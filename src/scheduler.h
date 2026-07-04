/**
 * The Forgotten Server - a free and open-source MMORPG server emulator
 * Copyright (C) 2020  Mark Samman <mark.samman@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef FS_SCHEDULER_H_2905B3D5EAB34B4BA8830167262D2DC1
#define FS_SCHEDULER_H_2905B3D5EAB34B4BA8830167262D2DC1

#include "tasks.h"
#include <atomic>
#include <mutex>
#include <vector>
#include <unordered_set>
#include <chrono>

#include "thread_holder_base.h"

static constexpr int32_t SCHEDULER_MINTICKS = 50;

#define createSchedulerTask(delay, func) std::make_unique<SchedulerTask>(delay, func)

class SchedulerTask;
using SchedulerTaskPtr = std::unique_ptr<SchedulerTask>;

class SchedulerTask : public Task
{
	public:
		SchedulerTask(uint32_t delay, std::function<void(void)>&& f) : Task(std::move(f)), delay(delay) {}

		void setEventId(uint64_t id) {
			eventId = id;
		}
		uint64_t getEventId() const {
			return eventId;
		}
		uint32_t getDelay() const {
			return delay;
		}

	private:
		uint64_t eventId = 0;
		uint32_t delay = 0;
};

class Scheduler : public ThreadHolder<Scheduler>
{
	public:
		Scheduler() = default;

		// non-copyable
		Scheduler(const Scheduler&) = delete;
		void operator=(const Scheduler&) = delete;

		uint64_t addEvent(SchedulerTaskPtr task);
		void stopEvent(uint64_t eventId);

		void shutdown();

		void threadMain() { io_context.run(); }

	private:
		using Clock = std::chrono::steady_clock;
		using TimePoint = Clock::time_point;

		struct Entry {
			TimePoint deadline;
			uint64_t id;
			SchedulerTaskPtr task;
			// min-heap: earlier deadline = higher priority
			bool operator>(const Entry& o) const { return deadline > o.deadline; }
		};

		void scheduleTimer();

		std::atomic<uint64_t> lastEventId{0};
		boost::asio::io_context io_context;
		boost::asio::io_context::work work{io_context};
		boost::asio::steady_timer timer{io_context};

		// only accessed on io_context thread — no mutex needed
		TimePoint currentTimerDeadline = TimePoint::max();

		// prevents flooding io_context with redundant scheduleTimer posts
		std::atomic<bool> kickPending{false};

		std::mutex mtx;
		std::vector<Entry> heap; // min-heap maintained via push_heap/pop_heap
		std::unordered_set<uint64_t> cancelled;
};

extern Scheduler g_scheduler;

#endif
