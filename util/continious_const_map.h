#ifndef _continious_const_map_h_
#define _continious_const_map_h_

#include <cstddef>
#include <functional>
#include <iterator>
#include <memory>
#include <new>
#include <stdexcept>
#include <string_view>
#include <unordered_map>
#include <utility>

/** Stores values of type T in one contiguous block of memory, indexed by key.
  * Values are never moved once constructed, so pointers/references to them stay
  * valid for the lifetime of the container (moving the container keeps the block
  * address intact). Keys are held in a hash index; iteration order is unspecified. */
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
    using size_type = std::size_t;
    using difference_type = std::ptrdiff_t;

    class const_iterator {
    public:
        // std::unordered_map iterators are forward-only. Claiming bidirectional here
        // makes std::ranges instantiate operator-- on them, which does not compile.
        using iterator_category = std::forward_iterator_tag;
        // Both the key and the value are handed out as references to objects that
        // live in the container (a prvalue pair here would copy the key and leave
        // callers holding a reference into a dead temporary).  value_type is kept
        // identical to reference so the range satisfies the std::ranges concepts.
        using reference = std::pair<const Key&, const T&>;
        using value_type = reference;
        using difference_type = continious_const_map::difference_type;

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

        using pointer = pointer_proxy;

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

    /** Builds the container from a range of {key, constructor-args-tuple} pairs. */
    template <typename Rng>
    explicit continious_const_map(Rng&& source) {
        const size_type capacity = std::size(source);
        if (capacity == 0)
            return;

        m_capacity = capacity;
        m_index_map.reserve(capacity);
        m_data = std::allocator_traits<std::allocator<T>>::allocate(m_alloc, capacity);

        try {
            for (auto& [key, init_args_tuple] : source) {
                if (m_size == capacity) { // source yielded more elements than std::size() reported
                    throw std::length_error("continious_const_map: source range exceeded its size()");
                }

                const size_type index = m_size;
                std::apply([this, index](auto&&... args) {
                    std::construct_at(m_data + index, std::forward<decltype(args)>(args)...);
                }, std::move(init_args_tuple));

                ++m_size; // from here on the cleanup code owns this element

                auto [it, inserted] = m_index_map.emplace(std::move(key), m_data + index);
                if (!inserted) { // duplicate key: drop the freshly constructed value
                    std::destroy_at(m_data + index);
                    --m_size;
                }
            }
        } catch (...) {
            for (size_t i = 0; i < m_size; ++i)
                std::destroy_at(m_data + i);
            std::allocator_traits<std::allocator<T>>::deallocate(m_alloc, m_data, m_capacity);
            m_data = nullptr;
            m_size = 0;
            m_capacity = 0;
            throw;
        }
    }

    continious_const_map(continious_const_map&& other) noexcept :
        m_size(std::exchange(other.m_size, 0)),
        m_capacity(std::exchange(other.m_capacity, 0)),
        m_data(std::exchange(other.m_data, nullptr)),
        m_alloc(std::move(other.m_alloc)),
        m_index_map(std::move(other.m_index_map))
    { }

    ~continious_const_map() {
        if (m_data) {
            for (size_t i = 0; i < m_size; ++i)
                std::destroy_at(m_data + i);
            std::allocator_traits<std::allocator<T>>::deallocate(m_alloc, m_data, m_capacity);
        }
    }

    continious_const_map& operator=(continious_const_map&& other) noexcept {
        if (this != &other) {
            if (m_data) {
                for (size_t i = 0; i < m_size; ++i)
                    std::destroy_at(m_data + i);
                std::allocator_traits<std::allocator<T>>::deallocate(m_alloc, m_data, m_capacity);
            }

            m_size = std::exchange(other.m_size, 0);
            m_capacity = std::exchange(other.m_capacity, 0);
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

    size_type size() const noexcept
    { return m_size; }

    bool empty() const noexcept
    { return m_size == 0; }

private:
    size_type m_size = 0;       // constructed elements
    size_type m_capacity = 0;   // T slots allocated for m_data
    T* m_data = nullptr;
    std::allocator<T> m_alloc;
    MapType m_index_map;
};

#endif // _continious_const_map_h_
