#pragma once            // Prevents header from being included multiple times
#include <winsock2.h>
#include <ws2tcpip.h>
#include <string>
#include <vector>
#include <cstdint>

class EthSender {
private:
    SOCKET data_socket;
    sockaddr_in server_addr;
    bool is_initialised;

public:
    // Constructor handles WSAStartup and socket creation
    EthSender(const std::string& ip_address, int port);

    // Destructor handles closesocket and WSACleanup
    ~EthSender();

    // Sends the vector of audio data over Ethernet
    bool sendData(const std::vector<int16_t>& data, uint32_t sample_rate);
};