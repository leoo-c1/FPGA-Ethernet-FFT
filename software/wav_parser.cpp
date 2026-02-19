#include <array>
#include <cstddef>
#include <vector>
#include <iostream>
#include <cstdint>
#include <string>
#include <fstream>
#include <cstring>

using namespace std;
ifstream is;

int file_length{0};

struct __attribute__((packed)) wav_header {
    // RIFF chunk descriptor
    char chunk_id[4]{};                 // 'RIFF', 4 characters
    uint32_t chunk_size{0};             // 4 bytes for size of the rest of the file after this
    char format[4]{};                   // 'WAVE', 4 characters

    // fmt chunk
    char fmt_id[4]{};                   // 'fmt ', 4 characters (including space)
    uint32_t fmt_size{};                // Size of the rest of the fmt chunk after this    
    uint16_t audio_format{};            // Audio format, should equal 1 for PCM
    uint16_t num_channels{};            // Mono = 1, stereo = 2
    uint32_t sample_rate{};             // Sample rate in hertz, such as 8000 or 44.1k
    uint32_t byte_rate{};               // = SampleRate * NumChannels * BitsPerSample/8
    uint16_t block_align{};             // = NumChannels * BitsPerSample/8
    uint16_t bits_per_sample{};         // Bit depth, 8-bit = 8, 16-bit = 16, etc

    // data header
    char data_id[4]{};                  // 'data', 4 characters
    uint32_t data_size{};               // = NumSamples * NumChannels * BitsPerSample/8
};

std::vector<int16_t> readWAVFile(string filename) {
    // Open the wav file
    is.open(filename, ios::binary);

    // If it isn't open, return an error
    if (!is.is_open()) {
        cout << "Could not open the wav file" << std::endl;
        return {};
    }

    // Get length of the wav file
    is.seekg(0,ios::end);
    file_length = is.tellg();
    is.seekg(0, ios::beg);

    // Create a wav_header struct
    wav_header header;
     // Read from the file
    is.read(reinterpret_cast<char*>(&header), sizeof(wav_header));

    if (strncmp(header.chunk_id, "RIFF", 4) != 0) {
        std::cout << "Error: Did not receive chunk ID 'RIFF'" << std::endl;
        return {};
    }
    if (strncmp(header.format, "WAVE", 4) != 0) {
        std::cout << "Error: Did not receive format 'WAVE'" << std::endl;
        return {};
    }
    if (strncmp(header.fmt_id, "fmt ", 4) != 0) {
        std::cout << "Error: Did not receive fmt ID 'fmt '" << std::endl;
        return {};
    }
    if (header.audio_format != 1) {
        std::cout << "Error: Audio format is not PCM" << std::endl;
        return {};
    }
    if (header.num_channels != 1) {
        std::cout << "Error: Audio is not mono" << std::endl;
        return {};
    }
    if (header.byte_rate != (header.sample_rate * header.num_channels * header.bits_per_sample/8)) {
        std::cout << "Error: Invalid byte rate" << std::endl;
        return {};
    }
    if (header.block_align != (header.num_channels * header.bits_per_sample/8)) {
        std::cout << "Error: Invalid block align" << std::endl;
        return {};
    }
    if (header.bits_per_sample != 16) {
        std::cout << "Error: Bit depth is not 16-bit" << std::endl;
        return {};
    }

    // With 16-bit audio, there are 2 bytes for every sample
    int num_samples = header.data_size / 2;
    // Create vector to hold audio data
    std::vector<int16_t> audio_data(num_samples);

    // Read the audio data
    is.read(reinterpret_cast<char*>(audio_data.data()), header.data_size);

    return audio_data;
}

int main() {
    std::cout << "Reading wav file..." << std::endl;
    readWAVFile("../audio/example_wav_mono.wav");
    is.close();
}

