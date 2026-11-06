#ifndef _continious_const_map_h_
#define _continious_const_map_h_

#include <memory>
#include <unordered_map>
#include <utility>

template <typename Key, typename T>
class continious_const_map {
private:
    struct transparent_string_hash {
        using is_transparent = void;

        std::size_t operator()(std::string_view sv) const noexcept {
            return std::hash<std::string_view>{}(sv);
        }
    };

    using MapType = std::unordered_map<Key, const T*, transparent_string_hash, std::equal_to<>>;
public:
    using key_type = Key;
    using mapped_type = const T;
    using value_type = std::pair<const Key, const T>;
    using size_type = size_t;
    using difference_type = ptrdiff_t;

    class const_iterator {
    public:
        using iterator_category = std::bidirectional_iterator_tag;
        using value_type = continious_const_map::value_type;
        using difference_type = continious_const_map::difference_type;
        using pointer = const value_type*;
        using reference = std::pair<const Key, const T&>;

        const_iterator() = default;

        explicit const_iterator(typename MapType::const_iterator it) :
            m_it(it)
        { }

        reference operator*() const
        { return { m_it->first, *(m_it->second) }; }

        class pointer_proxy {
            reference m_val;
        public:
            explicit pointer_proxy(reference v) :
                m_val(v)
            { }

            const reference* operator->() const
            { return &m_val; }
        };

        pointer_proxy operator->() const {
            return pointer_proxy{ **this };
        }

        const_iterator& operator++() {
            ++m_it;
            return *this;
        }

        const_iterator operator++(int) {
            auto tmp = *this;
            ++m_it;
            return tmp;
        }

        const_iterator& operator--() {
            --m_it;
            return *this;
        }

        const_iterator operator--(int) {
            auto tmp = *this;
            --m_it;
            return tmp;
        }

        friend bool operator==(const const_iterator& a, const const_iterator& b) {
            return a.m_it == b.m_it;
        }

        friend bool operator!=(const const_iterator& a, const const_iterator& b) {
            return a.m_it != b.m_it;
        }
    private:
        typename MapType::const_iterator m_it;
    };

    using iterator = const_iterator;

    continious_const_map()
    { }

    template <typename Rng>
    explicit continious_const_map(Rng&& source) :
        m_size(std::size(source))
    {
        if (m_size == 0)
            return;
        m_data = std::allocator_traits<std::allocator<T>>::allocate(m_alloc, m_size);
        size_t constructed_count = 0;
        try {
            for (auto& [key, init_args_tuple] : source) {
                std::apply([this, constructed_count](auto&&... args) {
                    std::construct_at(m_data + constructed_count, std::forward<decltype(args)>(args)...);
                }, std::move(init_args_tuple));

                m_index_map[std::move(key)] = m_data + constructed_count;
                ++constructed_count;
            }
        } catch (...) {
            for (size_t i = 0; i < constructed_count; ++i) {
                std::destroy_at(m_data + i);
            }
            std::allocator_traits<std::allocator<T>>::deallocate(m_alloc, m_data, m_size);
            m_data = nullptr;
            m_size = 0;
            throw;
        }
    }

    continious_const_map(continious_const_map&& other) noexcept :
        m_size(std::exchange(other.m_size, 0)),
        m_data(std::exchange(other.m_data, nullptr)),
        m_alloc(std::move(other.m_alloc)),
        m_index_map(std::move(other.m_index_map))
    { }

    ~continious_const_map() {
        if (m_data) {
            for (size_t i = 0; i < m_size; ++i)
                std::destroy_at(m_data + i);
            std::allocator_traits<std::allocator<T>>::deallocate(m_alloc, m_data, m_size);
        }
    }

    continious_const_map& operator=(continious_const_map&& other) noexcept {
        if (this != &other) {
            if (m_data) {
                for (size_t i = 0; i < m_size; ++i)
                    std::destroy_at(m_data + i);
                std::allocator_traits<std::allocator<T>>::deallocate(m_alloc, m_data, m_size);
            }

            m_size = std::exchange(other.m_size, 0);
            m_data = std::exchange(other.m_data, nullptr);
            m_alloc = std::move(other.m_alloc);
            m_index_map = std::move(other.m_index_map);
        }
        return *this;
    }

    continious_const_map(const continious_const_map&) = delete;
    continious_const_map& operator=(const continious_const_map&) = delete;

    const_iterator begin() const noexcept
    { return const_iterator(m_index_map.begin()); }

    const_iterator end() const noexcept
    { return const_iterator(m_index_map.end()); }

    const_iterator cbegin() const noexcept
    { return begin(); }

    const_iterator cend() const noexcept
    { return end(); }

    const_iterator find(const Key& key) const
    { return const_iterator(m_index_map.find(key)); }

    template<typename K>
    const_iterator find(const K& key) const
    { return const_iterator(m_index_map.find(key)); }

    size_t size() const noexcept
    { return m_size; }

    bool empty() const noexcept
    { return m_size == 0; }
private:
    size_t m_size = 0;
    T* m_data = nullptr;
    std::allocator<T> m_alloc;
    MapType m_index_map;
};

#endif // _continious_const_map_h_