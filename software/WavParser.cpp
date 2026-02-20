#include "WavParser.h"
#include <array>
#include <vector>
#include <iostream>
#include <cstdint>
#include <string>
#include <fstream>
#include <cstring>

using namespace std;

WavParser::WavParser(const string& file_path) {
    filename = file_path;
    file_length = 0;
}

bool WavParser::parse() {
    // Open the wav file
    cout << "Opening wav file..." << endl;
    ifstream is(filename, ios::binary);

    // If it isn't open, return an error
    if (!is.is_open()) {
        cout << "Could not open the wav file" << endl;
        return false;
    }

    // Get length of the wav file
    is.seekg(0,ios::end);
    file_length = is.tellg();
    is.seekg(0, ios::beg);

    // Create a wav_header struct
    wav_header header;
     // Read from the file
    cout << "Reading wav file..." << endl;
    is.read(reinterpret_cast<char*>(&header), sizeof(wav_header));

    // Store sample rate
    sample_rate = header.sample_rate;

    if (strncmp(header.chunk_id, "RIFF", 4) != 0) {
        cout << "Error: Did not receive chunk ID 'RIFF'" << endl;
        return false;
    }
    if (strncmp(header.format, "WAVE", 4) != 0) {
        cout << "Error: Did not receive format 'WAVE'" << endl;
        return false;
    }
    if (strncmp(header.fmt_id, "fmt ", 4) != 0) {
        cout << "Error: Did not receive fmt ID 'fmt '" << endl;
        return false;
    }
    if (header.audio_format != 1) {
        cout << "Error: Audio format is not PCM" << endl;
        return false;
    }
    if (header.num_channels != 1) {
        cout << "Error: Audio is not mono" << endl;
        return false;
    }
    if (header.byte_rate != (header.sample_rate * header.num_channels * header.bits_per_sample/8)) {
        cout << "Error: Invalid byte rate" << endl;
        return false;
    }
    if (header.block_align != (header.num_channels * header.bits_per_sample/8)) {
        cout << "Error: Invalid block align" << endl;
        return false;
    }
    if (header.bits_per_sample != 16) {
        cout << "Error: Bit depth is not 16-bit" << endl;
        return false;
    }

    // Skip any extra bytes in the fmt chunk if it's larger than 16 bytes
    if (header.fmt_size > 16) {
        is.seekg(header.fmt_size - 16, ios::cur);
    }

    char current_chunk_id[4];
    uint32_t current_chunk_size;

    // Loop through remaining chunks until we find 'data'
    while (true) {
        // Read the 4-byte ID and 4-byte size of the next chunk
        is.read(current_chunk_id, 4);
        is.read(reinterpret_cast<char*>(&current_chunk_size), 4);

        // Return an error if we hit the end of the file without finding the data chunk
        if (is.eof()) {
            cout << "Error: Reached end of file without finding data chunk" << endl;
            return false;
        }

        // Check if the chunk ID is 'data'
        if (strncmp(current_chunk_id, "data", 4) == 0) {
            break;
        }

        // If it is not 'data', skip past this chunk's payload
        is.seekg(current_chunk_size, ios::cur);
    }

    current_chunk_size = file_length - (int)is.tellg();

    // With 16-bit audio, there are 2 bytes for every sample
    int num_samples = current_chunk_size / 2;
    // Resize class object audio_data to fit num_samples
    audio_data.resize(num_samples);

    // Read the audio data
    is.read(reinterpret_cast<char*>(audio_data.data()), current_chunk_size);

    // Close the wav file
    cout << "Finished reading wav file" << endl;
    is.close();

    return true;
}

// Getter function for main.cpp to access the parsed data
const vector<int16_t>& WavParser::getAudioData() const {
    return audio_data;
}

// Getter function for main.cpp to access the sample rate
uint32_t WavParser::getSampleRate() const {
    return sample_rate;
}