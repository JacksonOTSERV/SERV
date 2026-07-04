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

#include "otpch.h"

#include "scheduler.h"

uint64_t Scheduler::addEvent(SchedulerTaskPtr task)
{
	if (task->getEventId() == 0) {
		task->setEventId(++lastEventId);
	}

	const uint64_t id = task->getEventId();
	auto deadline = Clock::now() + std::chrono::milliseconds(task->getDelay());

	bool needsKick = false;
	{
		std::lock_guard<std::mutex> lock(mtx);
		bool wasEmpty = heap.empty();
		bool isEarlier = !heap.empty() && deadline < heap.front().deadline;
		heap.push_back({deadline, id, std::move(task)});
		std::push_heap(heap.begin(), heap.end(), std::greater<Entry>{});
		needsKick = wasEmpty || isEarlier;
	}

	// Only post one scheduleTimer at a time — prevents cascading cancellations
	if (needsKick && !kickPending.exchange(true)) {
		boost::asio::post(io_context, [this]() {
			kickPending.store(false);
			scheduleTimer();
		});
	}

	return id;
}

void Scheduler::stopEvent(uint64_t eventId)
{
	if (eventId == 0) {
		return;
	}

	std::lock_guard<std::mutex> lock(mtx);
	cancelled.insert(eventId);
}

void Scheduler::scheduleTimer()
{
	std::unique_lock<std::mutex> lock(mtx);

	// drain cancelled entries from the top
	while (!heap.empty() && cancelled.count(heap.front().id)) {
		cancelled.erase(heap.front().id);
		std::pop_heap(heap.begin(), heap.end(), std::greater<Entry>{});
		heap.pop_back();
	}

	if (heap.empty()) {
		currentTimerDeadline = TimePoint::max();
		return;
	}

	auto nextDeadline = heap.front().deadline;
	lock.unlock();

	// Already armed for the right time — no-op, avoids cascading cancellations
	if (nextDeadline == currentTimerDeadline) {
		return;
	}

	currentTimerDeadline = nextDeadline;
	timer.expires_at(nextDeadline);
	timer.async_wait([this](const boost::system::error_code& ec) {
		if (getState() == THREAD_STATE_TERMINATED) {
			return;
		}

		// Timer was cancelled because an earlier event was added.
		// currentTimerDeadline already reflects the new deadline — DON'T reset it.
		// scheduleTimer() will see currentTimerDeadline == nextDeadline and no-op,
		// breaking the cascade of cancellations.
		if (ec == boost::asio::error::operation_aborted) {
			scheduleTimer();
			return;
		}

		// Normal fire — reset so scheduleTimer re-arms for the next event
		currentTimerDeadline = TimePoint::max();

		auto now = Clock::now();

		std::vector<SchedulerTaskPtr> toDispatch;
		{
			std::lock_guard<std::mutex> lock(mtx);
			while (!heap.empty() && heap.front().deadline <= now) {
				std::pop_heap(heap.begin(), heap.end(), std::greater<Entry>{});
				Entry entry = std::move(heap.back());
				heap.pop_back();
				if (!cancelled.count(entry.id)) {
					toDispatch.push_back(std::move(entry.task));
				} else {
					cancelled.erase(entry.id);
				}
			}
		}

		for (auto& t : toDispatch) {
			g_dispatcher.addTask(std::move(t));
		}

		scheduleTimer();
	});
}

void Scheduler::shutdown()
{
	setState(THREAD_STATE_TERMINATED);
	boost::asio::post(io_context, [this]() {
		timer.cancel();
		io_context.stop();
	});
}
