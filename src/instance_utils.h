#ifndef FS_INSTANCE_UTILS_H
#define FS_INSTANCE_UTILS_H

#include "creature.h"
#include "item.h"
#include "player.h"
#include "spectators.h"

#include <cstdint>

namespace InstanceUtils {

// Returns true if a player in 'viewerInstanceId' should see 'item'.
// Rules:
//   - Viewer sees items that share its exact instance.
//   - Viewer also sees items with instanceID 0 ONLY if they are map-loaded
//     (terrain/decorations placed in the map file, not dropped by players).
//   - Items dropped in instance 0 by a player (isLoadedFromMap == false) are
//     NOT visible to players in other instances.
inline bool canSeeItemInInstance(uint32_t viewerInstanceId, const Item* item)
{
	if (!item) {
		return false;
	}

	const uint32_t itemInstanceId = item->getInstanceID();

	// Same instance: always visible.
	if (itemInstanceId == viewerInstanceId) {
		return true;
	}

	// Item belongs to a different specific instance -> never visible.
	if (itemInstanceId != 0) {
		return false;
	}

	// itemInstanceId == 0 here.
	// Only show to other instances if it is a genuine map tile (loaded from map file).
	// If the viewer is also on instance 0, the first check already matched above.
	return item->isLoadedFromMap();
}

// Filter spectators: only keep players whose instanceID exactly matches 'instanceId'.
// No special treatment for instanceId == 0 — players in instance 0 only receive
// packets intended for instance 0.
template<typename Container>
inline SpectatorVec filterByInstance(const Container& spectators, uint32_t instanceId)
{
	SpectatorVec filtered;
	for (Creature* spectator : spectators) {
		const Player* p = spectator->getPlayer();
		if (p && p->getInstanceID() == instanceId) {
			filtered.emplace_back(spectator);
		}
	}
	return filtered;
}

inline SpectatorVec filterByInstance(const SpectatorVec& spectators, uint32_t instanceId)
{
	SpectatorVec filtered;
	for (Creature* spectator : spectators) {
		const Player* p = spectator->getPlayer();
		if (p && p->getInstanceID() == instanceId) {
			filtered.emplace_back(spectator);
		}
	}
	return filtered;
}

inline bool canInteract(const Creature* a, const Creature* b)
{
	return a && b && a->getInstanceID() == b->getInstanceID();
}

inline void sendMagicEffectToInstance(const SpectatorVec& spectators,
                                      const Position& pos, uint8_t effect,
                                      uint32_t instanceId)
{
	for (Creature* spectator : spectators) {
		Player* p = spectator->getPlayer();
		if (p && p->getInstanceID() == instanceId) {
			p->sendMagicEffect(pos, effect);
		}
	}
}

void sendMagicEffectToInstance(const Position& pos, uint32_t instanceId, uint8_t effect);

inline void sendDistanceEffectToInstance(const SpectatorVec& spectators,
                                         const Position& from,
                                         const Position& to, uint8_t effect,
                                         uint32_t instanceId)
{
	for (Creature* spectator : spectators) {
		Player* p = spectator->getPlayer();
		if (p && p->getInstanceID() == instanceId) {
			p->sendDistanceShoot(from, to, effect);
		}
	}
}

} // namespace InstanceUtils

#endif // FS_INSTANCE_UTILS_H
