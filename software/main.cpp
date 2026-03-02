#define _USE_MATH_DEFINES
#include <cmath>
#include <iostream>
#include <vector>
#include <thread>
#include <chrono>
#include <atomic>
#include "EthSender.h"
#include <windows.h>
#include <mmsystem.h>
#include "WavParser.h"

#pragma comment(lib, "winmm.lib")       
#pragma comment(lib, "comdlg32.lib")

// GUI state variables
std::string selected_wav_path = "";
std::atomic<bool> is_playing(false);
std::atomic<bool> stop_requested(false);

// GUI element handlers
HWND hPathLabel;
HWND hBtnSelect, hBtnStart, hBtnStop;

// Background audio and network thread
void AudioStreamingTask(std::string wav_file_path, std::string fpga_ip, int fpga_port) {
    is_playing = true;
    timeBeginPeriod(1);

    std::cout << "Starting wav parser..." << std::endl;
    WavParser parser(wav_file_path);
    
    if (!parser.parse()) {
        std::cout << "Error: Unable to parse wav file" << std::endl;
        is_playing = false;
        timeEndPeriod(1);
        return;
    }

    const std::vector<int16_t>& audio_track = parser.getAudioData();
    uint32_t file_sample_rate = parser.getSampleRate();
    std::cout << "Loaded " << audio_track.size() << " total samples into memory" << std::endl;

    std::cout << "Starting ethernet sender" << std::endl;
    EthSender sender(fpga_ip, fpga_port);

    WAVEFORMATEX wfx = {0};
    wfx.wFormatTag = WAVE_FORMAT_PCM;
    wfx.nChannels = 1;
    wfx.nSamplesPerSec = file_sample_rate;
    wfx.wBitsPerSample = 16;
    wfx.nBlockAlign = (wfx.nChannels * wfx.wBitsPerSample) / 8;
    wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;
    wfx.cbSize = 0;

    HWAVEOUT hWaveOut;
    if (waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL) != MMSYSERR_NOERROR) {
        std::cout << "Error: Failed to open system audio device" << std::endl;
        is_playing = false;
        timeEndPeriod(1);
        return;
    }

    WAVEHDR waveHeader = {0};
    waveHeader.lpData = (LPSTR)audio_track.data();
    waveHeader.dwBufferLength = audio_track.size() * sizeof(int16_t);
    
    waveOutPrepareHeader(hWaveOut, &waveHeader, sizeof(WAVEHDR));
    
    std::cout << "Starting audio playback" << std::endl;
    waveOutWrite(hWaveOut, &waveHeader, sizeof(WAVEHDR));

    const size_t FRAME_SIZE = 1024;
    
    // Precompute the Hann window
    std::vector<double> hann_window(FRAME_SIZE);
    for (size_t i = 0; i < FRAME_SIZE; ++i) {
        hann_window[i] = 0.5 * (1.0 - std::cos(2.0 * M_PI * i / (FRAME_SIZE - 1)));
    }

    size_t total_samples = audio_track.size();
    auto playback_start_time = std::chrono::steady_clock::now();

    for (size_t i = 0; i + FRAME_SIZE <= total_samples; i += FRAME_SIZE) {
        if (stop_requested) break;          

        std::vector<int16_t> frame(audio_track.begin() + i, audio_track.begin() + i + FRAME_SIZE);

        // Apply the Hann window to the frame
        for (size_t j = 0; j < FRAME_SIZE; ++j) {
            frame[j] = static_cast<int16_t>(frame[j] * hann_window[j]);
        }

        auto frame_end_time = playback_start_time + std::chrono::microseconds( ((i + FRAME_SIZE) * 1000000ULL) / file_sample_rate );

        // Send the frame once
        sender.sendFrame(frame);

        if (stop_requested) break;
        
        // Wait until it is time for the next audio frame
        std::this_thread::sleep_until(frame_end_time);
    }
    
    std::cout << "Stream ended" << std::endl;

    if (stop_requested) {
        waveOutReset(hWaveOut);     // Instantly stop the audio buffer
    } else {
        std::cout << "Waiting for audio playback to finish" << std::endl;
        while (!(waveHeader.dwFlags & WHDR_DONE)) {
            if (stop_requested) { waveOutReset(hWaveOut); break; }
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    }

    waveOutUnprepareHeader(hWaveOut, &waveHeader, sizeof(WAVEHDR));
    waveOutClose(hWaveOut);
    timeEndPeriod(1);

    is_playing = false;
    stop_requested = false;
    std::cout << "Ready for next file" << std::endl;
}

// GUI handler
LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
        case WM_COMMAND:
            if (LOWORD(wParam) == 1) {      // Select File Button
                OPENFILENAMEA ofn;
                char szFile[260] = {0};
                ZeroMemory(&ofn, sizeof(ofn));
                ofn.lStructSize = sizeof(ofn);
                ofn.hwndOwner = hwnd;
                ofn.lpstrFile = szFile;
                ofn.nMaxFile = sizeof(szFile);
                ofn.lpstrFilter = "WAV Files\0*.wav\0All Files\0*.*\0";
                ofn.nFilterIndex = 1;
                ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

                if (GetOpenFileNameA(&ofn)) {
                    selected_wav_path = ofn.lpstrFile;
                    SetWindowTextA(hPathLabel, selected_wav_path.c_str());
                }
            }
            else if (LOWORD(wParam) == 2) {      // Start Button
                if (!is_playing && !selected_wav_path.empty()) {
                    stop_requested = false;
                    // Detach thread to run in background without blocking GUI
                    std::thread(AudioStreamingTask, selected_wav_path, "192.0.2.146", 5005).detach();
                } else if (selected_wav_path.empty()) {
                    MessageBoxA(hwnd, "Please select a WAV file first", "Error", MB_ICONWARNING);
                }
            }
            else if (LOWORD(wParam) == 3) {     // Stop Button
                if (is_playing) {
                    stop_requested = true;
                }
            }
            break;

        case WM_DESTROY:
            stop_requested = true;              // Ensure thread dies if window is closed
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

int main() {
    // Register the window class
    WNDCLASSA wc = {0};
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = GetModuleHandle(NULL);
    wc.lpszClassName = "FPGAVisClass";
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW+1);

    RegisterClassA(&wc);

    // Create the window
    HWND hwnd = CreateWindowExA(
        0, "FPGAVisClass", "FPGA Audio Visualiser Controller",
        WS_OVERLAPPEDWINDOW ^ WS_THICKFRAME ^ WS_MAXIMIZEBOX,   // Make window non-resizable
        CW_USEDEFAULT, CW_USEDEFAULT, 400, 200,
        NULL, NULL, wc.hInstance, NULL
    );

    // Create GUI Controls
    hBtnSelect = CreateWindowA("BUTTON", "Select WAV File", WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
                                20, 20, 150, 30, hwnd, (HMENU)1, wc.hInstance, NULL);

    hPathLabel = CreateWindowA("STATIC", "No file selected", WS_VISIBLE | WS_CHILD,
                                20, 60, 340, 40, hwnd, NULL, wc.hInstance, NULL);

    hBtnStart = CreateWindowA("BUTTON", "START", WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_PUSHBUTTON,
                                20, 110, 100, 30, hwnd, (HMENU)2, wc.hInstance, NULL);

    hBtnStop = CreateWindowA("BUTTON", "STOP", WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_PUSHBUTTON,
                                140, 110, 100, 30, hwnd, (HMENU)3, wc.hInstance, NULL);

    ShowWindow(hwnd, SW_SHOW);

    // Run the Windows message loop
    MSG msg = {0};
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;
}