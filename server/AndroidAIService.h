#ifndef _AndroidAIService_h_
#define _AndroidAIService_h_

#include <string>
#include <vector>

class AndroidAIService {
public:
    AndroidAIService(int slot_id, const std::vector<std::string>& args);
    ~AndroidAIService();

    AndroidAIService(const AndroidAIService&) = delete;
    AndroidAIService& operator=(const AndroidAIService&) = delete;

    AndroidAIService(AndroidAIService&&) noexcept = default;
    AndroidAIService& operator=(AndroidAIService&&) noexcept = default;

    void Kill();
    void Free();
private:
    int m_slot_id;
    bool m_killed;
};

#endif
