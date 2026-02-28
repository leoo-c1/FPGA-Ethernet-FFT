#include <iostream>
#include <vector>
#include <thread>
#include <chrono>
#include "EthSender.h"
#include <windows.h>
#include <mmsystem.h>
#include "WavParser.h"

#pragma comment(lib, "winmm.lib")       // Link the Windows multimedia library

// GUI state variables
std::string selected_wav_path = "../audio/logarithmic_sweep.wav";   // Still hardcoded for now
std::string fpga_ip = "192.0.2.146";                                // FPGA's IP address
int fpga_port = 5005;                                               // FPGA's UDP port

// GUI Element Handles
HWND hPathLabel;
HWND hBtnSelect, hBtnStart, hBtnStop;

void AudioStreamingTask(std::string wav_file_path, std::string fpga_ip, int fpga_port) {
    timeBeginPeriod(1);

    // Instantiate the parser
    std::cout << "Starting wav parser..." << std::endl;
    WavParser parser(wav_file_path);
    
    // Check if parsing succeeded before continuing
    if (!parser.parse()) {
        std::cout << "Error: Unable to parse wav file" << std::endl;
        return;
    }

    // Retrieve the parsed audio data and sample rate
    const std::vector<int16_t>& audio_track = parser.getAudioData();
    uint32_t file_sample_rate = parser.getSampleRate();
    std::cout << "Loaded " << audio_track.size() << " total samples into memory" << std::endl;

    // Instantiate the Ethernet Sender
    std::cout << "Starting ethernet sender" << std::endl;
    EthSender sender(fpga_ip, fpga_port);

    // Setup audio buffer
    WAVEFORMATEX wfx = {0};
    wfx.wFormatTag = WAVE_FORMAT_PCM;
    wfx.nChannels = 1;
    wfx.nSamplesPerSec = file_sample_rate;
    wfx.wBitsPerSample = 16;
    wfx.nBlockAlign = (wfx.nChannels * wfx.wBitsPerSample) / 8;
    wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;
    wfx.cbSize = 0;

    HWAVEOUT hWaveOut;
    // Open the default audio device
    if (waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL) != MMSYSERR_NOERROR) {
        std::cout << "Error: Failed to open system audio device" << std::endl;
        return;
    }

    // Point the audio header to parsed data
    WAVEHDR waveHeader = {0};
    waveHeader.lpData = (LPSTR)audio_track.data();
    waveHeader.dwBufferLength = audio_track.size() * sizeof(int16_t);
    
    // Prepare waveoutWrite
    waveOutPrepareHeader(hWaveOut, &waveHeader, sizeof(WAVEHDR));
    
    std::cout << "Starting audio playback" << std::endl;
    waveOutWrite(hWaveOut, &waveHeader, sizeof(WAVEHDR));

    // Send data in aligned frames of 1024 samples
    const size_t FRAME_SIZE = 1024;
    size_t total_samples = audio_track.size();

    // Record the absolute time the playback started
    auto playback_start_time = std::chrono::steady_clock::now();

    // Step through the file 1024 samples at a time
    for (size_t i = 0; i + FRAME_SIZE <= total_samples; i += FRAME_SIZE) {
        
        // Extract the current frame
        std::vector<int16_t> frame(audio_track.begin() + i, audio_track.begin() + i + FRAME_SIZE);

        // Calculate the absolute time this frame should finish
        auto frame_end_time = playback_start_time + std::chrono::microseconds( ((i + FRAME_SIZE) * 1000000ULL) / file_sample_rate );
        
        // Send packets for a bit less than the frame duration to leave time for processing
        auto blast_end_time = frame_end_time - std::chrono::microseconds(1000);

        // Send as many copies as possible within the time limit
        while (std::chrono::steady_clock::now() < blast_end_time) {
            sender.sendFrame(frame);
        }

        // Sleep precisely until the absolute frame boundary
        std::this_thread::sleep_until(frame_end_time);
    }
    
    std::cout << "Contents of wav file have been sent" << std::endl;

    // Wait for the background audio buffer to finish playing
    std::cout << "Waiting for audio playback to finish" << std::endl;
    while (!(waveHeader.dwFlags & WHDR_DONE)) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    // Clean up audio resources
    waveOutUnprepareHeader(hWaveOut, &waveHeader, sizeof(WAVEHDR));
    waveOutClose(hWaveOut);

    timeEndPeriod(1);
    std::cout << "Ready for next file" << std::endl;
}

// GUI handler
LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
        case WM_COMMAND:
            if (LOWORD(wParam) == 1) {      // Select File Button
                // Implement file picker
            }
            else if (LOWORD(wParam) == 2) {      // Start Button
                AudioStreamingTask(selected_wav_path, fpga_ip, fpga_port);
            }
            else if (LOWORD(wParam) == 3) {     // Stop Button
                // Implement stop logic
            }
            break;

        case WM_DESTROY:
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