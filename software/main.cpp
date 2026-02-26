#include <iostream>
#include <vector>
#include <thread>
#include <chrono>
#include "WavParser.h"
#include "EthSender.h"

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
    std::cout << "Starting ethernet sender..." << std::endl;
    EthSender sender(fpga_ip, fpga_port);

    // Send data in aligned frames of 1024 samples
    const size_t FRAME_SIZE = 1024;
    size_t total_samples = audio_track.size();

    // Step through the file 1024 samples at a time
    for (size_t i = 0; i + FRAME_SIZE <= total_samples; i += FRAME_SIZE) {
        
        // Extract the current frame
        std::vector<int16_t> frame(audio_track.begin() + i, audio_track.begin() + i + FRAME_SIZE);

        // Send the same frame 10 times
        for (int repeat = 0; repeat < 100; repeat++) {
            sender.sendFrame(frame);
            // Tiny delay for safety
            std::this_thread::sleep_for(std::chrono::microseconds(10)); 
        }

        // Delay to match audio rate (approx 23ms for 1024 samples @ 44.1kHz)
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    
    std::cout << "Contents of wav file have been sent" << std::endl;

    return 0;
}