#ifndef _continious_const_map_h_
#define _continious_const_map_h_

#include <compare>
#include <cstddef>
#include <iterator>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <string_view>
#include <tuple>
#include <type_traits>
#include <unordered_map>
#include <utility>

/** Stores values of type T in one contiguous block of memory, indexed by
  * T::Name().  Values are constructed in place and never moved, so pointers and
  * references to them stay valid for the lifetime of the container (moving the
  * container keeps the block address intact).  T may therefore be immobile and
  * may hold self-referential state.
  *
  * T must be constructible in place from the tuple yielded by the source range
  * and expose a stable `const std::string& Name() const`.  The name is used as
  * the key, so the key is stored only once (inside T itself).  If several values
  * share a name, the first one wins and the later ones are destroyed.
  *
  * Iteration follows the order of the source range and walks the contiguous
  * buffer directly; the hash index is only used for lookups. */
template <typename T>
class continious_const_map {
public:
    // The name is used as the key and is not copied into the container, so it
    // has to stay alive inside the value.  Returning it by value would leave the
    // index pointing at a destroyed temporary.
    static_assert(std::is_lvalue_reference_v<decltype(std::declval<const T&>().Name())>,
                  "continious_const_map requires T::Name() to return a reference "
                  "to a string that lives as long as the T instance");

    using key_type = std::string;
    using mapped_type = const T;
    using value_type = std::pair<const key_type&, const T&>;
    using size_type = std::size_t;
    using difference_type = std::ptrdiff_t;

    class const_iterator {
    public:
        using iterator_category = std::random_access_iterator_tag;
        // Both the key and the value are handed out as references to objects
        // that live in the container (a prvalue pair here would copy the key
        // and leave callers holding a reference into a dead temporary).
        // value_type is kept identical to reference so the range satisfies the
        // std::ranges iterator concepts.
        using reference = continious_const_map::value_type;
        using value_type = reference;
        using difference_type = continious_const_map::difference_type;

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

        const_iterator() = default;

        explicit const_iterator(const T* ptr) :
            m_ptr(ptr)
        { }

        reference operator*() const
        { return { m_ptr->Name(), *m_ptr }; }

        pointer operator->() const
        { return pointer{ **this }; }

        const_iterator& operator++() {
            ++m_ptr;
            return *this;
        }

        const_iterator operator++(int) {
            auto tmp = *this;
            ++m_ptr;
            return tmp;
        }

        const_iterator& operator--() {
            --m_ptr;
            return *this;
        }

        const_iterator operator--(int) {
            auto tmp = *this;
            --m_ptr;
            return tmp;
        }

        const_iterator& operator+=(difference_type n) {
            m_ptr += n;
            return *this;
        }

        const_iterator& operator-=(difference_type n) {
            m_ptr -= n;
            return *this;
        }

        friend const_iterator operator+(const_iterator it, difference_type n) {
            it += n;
            return it;
        }

        friend const_iterator operator+(difference_type n, const_iterator it) {
            it += n;
            return it;
        }

        friend const_iterator operator-(const_iterator it, difference_type n) {
            it -= n;
            return it;
        }

        friend difference_type operator-(const const_iterator& a, const const_iterator& b)
        { return (a.m_ptr && b.m_ptr) ? a.m_ptr - b.m_ptr : difference_type{0}; }

        reference operator[](difference_type n) const
        { return *(*this + n); }

        friend bool operator==(const const_iterator& a, const const_iterator& b)
        { return a.m_ptr == b.m_ptr; }

        friend auto operator<=>(const const_iterator& a, const const_iterator& b)
        { return a.m_ptr <=> b.m_ptr; }

    private:
        const T* m_ptr = nullptr;
    };

    using iterator = const_iterator;

    continious_const_map() = default;

    /** Builds the container from a range of constructor-argument tuples. */
    template <typename Rng>
    explicit continious_const_map(Rng&& source) {
        const size_type capacity = std::size(source);
        if (capacity == 0)
            return;

        m_capacity = capacity;
        m_index_map.reserve(capacity);
        m_data = std::allocator_traits<std::allocator<T>>::allocate(m_alloc, capacity);

        try {
            for (auto& init_args_tuple : source) {
                if (m_size == capacity) { // source yielded more elements than std::size() reported
                    throw std::length_error("continious_const_map: source range exceeded its size()");
                }

                const size_type index = m_size;
                std::apply([this, index](auto&&... args) {
                    std::construct_at(m_data + index, std::forward<decltype(args)>(args)...);
                }, std::move(init_args_tuple));

                ++m_size; // from here on the cleanup code owns this element

                const T& value = m_data[index];
                auto [it, inserted] = m_index_map.emplace(std::string_view{value.Name()}, &value);
                if (!inserted) { // duplicate name: drop the freshly constructed value
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
    { return const_iterator(m_data); }

    const_iterator end() const noexcept
    { return const_iterator(m_data ? m_data + m_size : nullptr); }

    const_iterator cbegin() const noexcept
    { return begin(); }

    const_iterator cend() const noexcept
    { return end(); }

    const_iterator find(std::string_view key) const {
        const auto it = m_index_map.find(key);
        return it == m_index_map.end() ? end() : const_iterator(it->second);
    }

    size_type size() const noexcept
    { return m_size; }

    bool empty() const noexcept
    { return m_size == 0; }

private:
    size_type m_size = 0;       // constructed elements
    size_type m_capacity = 0;   // T slots allocated for m_data
    T* m_data = nullptr;
    std::allocator<T> m_alloc;
    std::unordered_map<std::string_view, const T*> m_index_map;
};

#endif // _continious_const_map_h_
