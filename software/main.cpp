#include <iostream>
#include <vector>
#include <thread>
#include <chrono>
#include "EthSender.h"
#include <windows.h>
#include <mmsystem.h>
#include "WavParser.h"

#pragma comment(lib, "winmm.lib")       // Link the Windows multimedia library

int main() {
    std::string wav_file_path = "../audio/example_wav_mono.wav";    // File path for wav audio
    std::string fpga_ip = "192.0.2.146";                            // FPGA's IP address
    int fpga_port = 5005;                                           // FPGA's UDP port

    // Instantiate the parser
    std::cout << "Starting wav parser..." << std::endl;
    WavParser parser(wav_file_path);
    
    // Check if parsing succeeded before continuing
    if (!parser.parse()) {
        std::cout << "Error: Unable to parse wav file" << std::endl;
        return 1;
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
        return 1;
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

    // Step through the file 1024 samples at a time
    for (size_t i = 0; i + FRAME_SIZE <= total_samples; i += FRAME_SIZE) {
        
        // Extract the current frame
        std::vector<int16_t> frame(audio_track.begin() + i, audio_track.begin() + i + FRAME_SIZE);

        // Send the same frame 200 times
        for (int repeat = 0; repeat < 200; repeat++) {
            sender.sendFrame(frame);
            // Tiny delay for safety
            std::this_thread::sleep_for(std::chrono::microseconds(1)); 
        }

        // Delay to match audio rate (approx 23ms for 1024 samples @ 44.1kHz)
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
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

    return 0;
}