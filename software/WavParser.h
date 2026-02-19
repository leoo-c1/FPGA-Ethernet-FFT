#pragma once // Prevents this header from being included multiple times
#include <vector>
#include <string>
#include <cstdint>
#include <fstream>

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
};

class WavParser {
private:
    std::string filename;
    std::vector<int16_t> audio_data;
    int file_length;

public:
    // Constructor
    WavParser(const std::string& file_path);
    
    // Destructor
    ~WavParser() = default; 

    // Public method to trigger the parsing
    bool parse();

    // Getter to retrieve the data safely
    const std::vector<int16_t>& getAudioData() const;
};