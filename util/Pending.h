#ifndef _Pending_h_
#define _Pending_h_

#include "Export.h"
#include "Logger.h"

#include <boost/filesystem/path.hpp>
#include <boost/optional/optional.hpp>

#include <future>
#include <mutex>
#include <string>

/** namespace Pending collection classes and functions used for
    asynchronously parsing universe types, statistics etc.*/
namespace Pending {
    /** Pending holds the std::future results of a T.*/
    template <typename T>
    struct FO_COMMON_API Pending {
        using result_type = T;

        Pending(boost::optional<std::future<T>>&& pending_,
                const std::string& name_) :
            pending(std::move(pending_)),
            filename(name_)
        {}

        Pending(Pending&& other) noexcept :
            pending(std::move(other.pending)),
            filename(std::move(other.filename))
        {}

        Pending& operator=(Pending&& other) noexcept {
            pending = std::move(other.pending);
            filename = std::move(other.filename);
            return *this;
        }

        boost::optional<std::future<T>> pending = boost::none;
        std::string filename;
        std::mutex m_mutex;
    };

    template <typename T>
    boost::optional<T> WaitForPendingUnlocked(Pending<T>&& pending, bool do_not_care_about_result = false) {
        std::future_status status;
        do {
            if (!pending.pending->valid()) {
                return boost::none;
            }

            status = pending.pending->wait_for(std::chrono::seconds(1));
            if (status == std::future_status::timeout)
                DebugLogger() << "Waiting for parse of \"" << pending.filename << "\" to complete.";

            if (status == std::future_status::deferred) {
                ErrorLogger() << "Pending parse is unable to handle deferred future.";
                throw "deferred future not handled";
            }
            DebugLogger() << "WaitForPendingUnlocked another wait_for round";
        } while (status != std::future_status::ready);

        try {
            // multiple threads might be waiting but not care about the results
            if (do_not_care_about_result) {
                if (pending.pending->valid()) {
                    DebugLogger() << "Dont care for result of parsing \"" << pending.filename << "\". Have to get() once to release shared state in pending future.";
                    pending.pending->get(); // needs to be called once to release state
                }
                DebugLogger() << "Dont care for result of parsing \"" << pending.filename << "\". Was already released.";
                return boost::none;
            }
            DebugLogger() << "Retrieve result of parsing \"" << pending.filename << "\".";
            auto x = std::move(pending.pending->get());
            DebugLogger() << "Retrieved result of parsing \"" << pending.filename << "\".";
            return std::move(x);
        } catch (const std::exception& e) {
            ErrorLogger() << "Parsing of \"" << pending.filename << "\" failed with error: " << e.what();
        }

        return boost::none;
    }
    /** Wait for the \p pending parse to complete.  Set pending to boost::none
        and return the parsed T. Destroys the shared state in the wrapped std::future.
        Return boost::none on errors.*/
    template <typename T>
    boost::optional<T> WaitForPending(boost::optional<Pending<T>>& pending, bool do_not_care_about_result = false) {
        if (!pending)
            return boost::none;
        std::lock_guard<std::mutex> lock(pending->m_mutex);
        if (!pending || !(pending->pending)) {
            // another thread in the meantime transferred the pending to stored
            return boost::none;
        }
        if (auto tt = WaitForPendingUnlocked(std::move(*pending), do_not_care_about_result)) {
            pending = boost::none;
            return tt;
        } else {
            pending = boost::none;
            return boost::none;
        }
    }

    /** If there is a pending parse, wait for it and swap it with the stored
        value.  Return the stored value.*/
    template <typename T>
    T& SwapPending(boost::optional<Pending<T>>& pending, T& stored) {
        if (pending) {
            std::lock_guard<std::mutex> lock(pending->m_mutex);
            if (!pending) {
                // another thread in the meantime transferred the pending to stored
                return stored;
            }
            if (auto tt = WaitForPendingUnlocked(std::move(*pending))) {
                std::swap(*tt, stored);
            }
	    pending = boost::none;
        }
        return stored;
    }

    /** Return a Pending<T> constructed with \p parser and \p path*/
    template <typename Func>
    auto StartParsing(const Func& parser, const boost::filesystem::path& path)
        -> Pending<decltype(parser(path))>
    {
        return Pending<decltype(parser(path))>(
            std::async(std::launch::async, parser, path), path.filename().string());
    }
}


#endif
