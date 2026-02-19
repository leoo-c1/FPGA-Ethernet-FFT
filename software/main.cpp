#include <iostream>
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

    // Retrieve the parsed audio data
    const std::vector<int16_t>& audio_track = parser.getAudioData();
    std::cout << "Loaded " << audio_track.size() << " total samples into memory" << std::endl;

    // Instantiate the Ethernet Sender
    std::cout << "Starting ethernet sender..." << std::endl;
    EthSender sender(fpga_ip, fpga_port);

    // Send the data to the FPGA
    if (sender.sendData(audio_track)) {
        std::cout << "Audio data has been sent to the FPGA" << std::endl;
    } else {
        std::cout << "Error: Failed to send audio data to the FPGA" << std::endl;
        return 1;
    }
    
    return 0;
}