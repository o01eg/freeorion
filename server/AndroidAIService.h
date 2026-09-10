#ifndef _AndroidAIService_h_
#define _AndroidAIService_h_

#include <string>

class AndroidAIService {
public:
    AndroidAIService(int slot_id, const std::string& player_name);
    ~AndroidAIService();

    AndroidAIService(const AndroidAIService&) = delete;
    AndroidAIService& operator=(const AndroidAIService&) = delete;

    AndroidAIService(AndroidAIService&&) noexcept = default;
    AndroidAIService& operator=(AndroidAIService&&) noexcept = default;

    void Kill();
private:
    int m_slot_id;
    bool m_killed;
};

#endif
