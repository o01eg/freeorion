#ifndef _AndroidAIService_h_
#define _AndroidAIService_h_

class AndroidAIService {
public:
    AndroidAIService(int slot_id);
    ~AndroidAIService();

    AndroidAIService(const AndroidAIService&) = delete;
    AndroidAIService& operator=(const AndroidAIService&) = delete;

    AndroidAIService(AndroidAIService&&) noexcept = default;
    AndroidAIService& operator=(AndroidAIService&&) noexcept = default;
private:
    int m_slot_id;
};

#endif
