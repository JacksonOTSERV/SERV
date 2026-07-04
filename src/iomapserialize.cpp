/**
 * The Forgotten Server - a free and open-source MMORPG server emulator
 * Copyright (C) 2019  Mark Samman <mark.samman@gmail.com>
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

#include "iomapserialize.h"
#include "game.h"
#include "bed.h"

extern Game g_game;

void IOMapSerialize::loadHouseItems(Map* map)
{
	int64_t start = OTSYS_TIME();

	DBResult_ptr result = Database::getInstance().storeQuery("SELECT `data` FROM `tile_store`");
	if (!result) {
		return;
	}

	do {
		unsigned long attrSize;
		const char* attr = result->getStream("data", attrSize);

		PropStream propStream;
		propStream.init(attr, attrSize);

		uint16_t x, y;
		uint8_t z;
		if (!propStream.read<uint16_t>(x) || !propStream.read<uint16_t>(y) || !propStream.read<uint8_t>(z)) {
			continue;
		}

		Tile* tile = map->getTile(x, y, z);
		if (!tile) {
			continue;
		}

		uint32_t item_count;
		if (!propStream.read<uint32_t>(item_count)) {
			continue;
		}

		while (item_count--) {
			loadItem(propStream, tile);
		}
	} while (result->next());
	std::cout << "> Itens de casas carregados em: " << (OTSYS_TIME() - start) / (1000.) << " s" << std::endl;
}

bool IOMapSerialize::saveHouseItems()
{
	int64_t start = OTSYS_TIME();
	Database& db = Database::getInstance();
	std::ostringstream query;

	//Start the transaction
	DBTransaction transaction;
	if (!transaction.begin()) {
		return false;
	}

	//clear old tile data
	if (!db.executeQuery("DELETE FROM `tile_store`")) {
		return false;
	}

	DBInsert stmt("INSERT INTO `tile_store` (`house_id`, `data`) VALUES ");

	PropWriteStream stream;
	for (auto& it : g_game.map.houses.getHouses()) {
		//save house items
		House* house = &it.second;
		for (HouseTile* tile : house->getTiles()) {
			saveTile(stream, tile);

			size_t attributesSize;
			const char* attributes = stream.getStream(attributesSize);
			if (attributesSize > 0) {
				query << house->getId() << ',' << db.escapeBlob(attributes, attributesSize);
				if (!stmt.addRow(query)) {
					return false;
				}
				stream.clear();
			}
		}
	}

	if (!stmt.execute()) {
		return false;
	}

	//End the transaction
	bool success = transaction.commit();
	std::cout << "> Itens de casas salvos em: " <<
	          (OTSYS_TIME() - start) / (1000.) << " s" << std::endl;
	return success;
}

bool IOMapSerialize::loadContainer(PropStream& propStream, Container* container)
{
	while (container->serializationCount > 0) {
		if (!loadItem(propStream, container)) {
			std::cout << "[Warning - IOMapSerialize::loadContainer] Unserialization error for container item: " << container->getID() << std::endl;
			return false;
		}
		container->serializationCount--;
	}

	uint8_t endAttr;
	if (!propStream.read<uint8_t>(endAttr) || endAttr != 0) {
		std::cout << "[Warning - IOMapSerialize::loadContainer] Unserialization error for container item: " << container->getID() << std::endl;
		return false;
	}
	return true;
}

bool IOMapSerialize::loadItem(PropStream& propStream, Cylinder* parent)
{
    Tile* tile = nullptr;
    if (!parent->getItem()) {
        tile = parent->getTile();
    }

    uint16_t id = 0;
    if (!propStream.read<uint16_t>(id)) {
        return false;
    }

    Item* item = nullptr;
    const ItemType& iType = Item::items[id];

    if (iType.moveable || iType.forceSerialize || !tile) {
        item = Item::CreateItem(id);
        if (!item) {
            return true;
        }

        if (!item->unserializeAttr(propStream)) {
            std::clog << "[Warning - IOMapSerialize::loadItem] Unserialization error [0] for item type " << id << std::endl;
            delete item;
            return false;
        }

        if (Container* container = item->getContainer()) {
            if (!loadContainer(propStream, container)) {
                delete item;
                return false;
            }
        }

        if (parent) {
            parent->internalAddThing(item);
            item->startDecaying();
        } else {
            delete item;
        }
        return true;
    }

    if (tile) {
        if (const TileItemVector* items = tile->getItemList()) {
            for (Item* findItem : *items) {
                if (findItem->getID() == id) {
                    item = findItem;
                    break;
                }
                if (iType.isBed() && findItem->getBed()) {
                    item = findItem;
                    break;
                }
                if (iType.isDoor() && findItem->getDoor()) {
                    item = findItem;
                    break;
                }
            }
        }
    }

    if (item) {
        if (item->unserializeAttr(propStream)) {
            Container* container = item->getContainer();
            if (container && !loadContainer(propStream, container)) {
                return false;
            }

            if (!item->getDoor()) {
                g_game.transformItem(item, id);
            }
        } else {
            std::clog << "[Warning - IOMapSerialize::loadItem] Unserialization error [1] for item type " << id << std::endl;
        }
        return true;
    }

    item = Item::CreateItem(id);
    if (!item) {
        return true;
    }

    item->unserializeAttr(propStream);
    if (Container* container = item->getContainer()) {
        if (!loadContainer(propStream, container)) {
            delete item;
            return false;
        }
    }

    delete item;
    return true;
}

bool IOMapSerialize::saveItem(PropWriteStream& stream, const Item* item)
{
    stream.write<uint16_t>(item->getID());
    item->serializeAttr(stream);

    if (const Container* container = item->getContainer()) {
        stream.write<uint8_t>(ATTR_CONTAINER_ITEMS);
        stream.write<uint32_t>(container->size());

        for (auto it = container->getReversedItems(), end = container->getReversedEnd(); it != end; ++it) {
            saveItem(stream, *it);
        }
    }

    stream.write<uint8_t>(0x00);
    return true;
}

bool IOMapSerialize::saveTile(PropWriteStream& stream, const Tile* tile)
{
    int32_t tileCount = tile->getThingCount();
    if (!tileCount) {
        return true;
    }

    std::vector<Item*> items;
    Item* item = nullptr;
    for (; tileCount > 0; --tileCount) {
        Thing* thing = tile->getThing(tileCount - 1);
        if (!thing) {
            continue;
        }

        item = thing->getItem();
        if (item) {
            const ItemType& it = Item::items[item->getID()];
            if (item->isMoveable() || it.forceSerialize) {
                items.push_back(item);
            }
        }
    }

    tileCount = static_cast<int32_t>(items.size());
    if (tileCount > 0) {
        const Position& pos = tile->getPosition();

        stream.write<uint16_t>(pos.x);
        stream.write<uint16_t>(pos.y);
        stream.write<uint8_t>(pos.z);

        stream.write<uint32_t>(tileCount);
        for (std::vector<Item*>::iterator it = items.begin(); it != items.end(); ++it) {
            saveItem(stream, *it);
        }
    }

    return true;
}

bool IOMapSerialize::loadHouseInfo()
{
	Database& db = Database::getInstance();

	DBResult_ptr result = db.storeQuery("SELECT `id`, `owner`, `paid`, `warnings` FROM `houses`");
	if (!result) {
		return false;
	}

	do {
		House* house = g_game.map.houses.getHouse(result->getNumber<uint32_t>("id"));
		if (house) {
			house->setOwner(result->getNumber<uint32_t>("owner"), false);
			house->setPaidUntil(result->getNumber<time_t>("paid"));
			house->setPayRentWarnings(result->getNumber<uint32_t>("warnings"));
		}
	} while (result->next());

	result = db.storeQuery("SELECT `house_id`, `listid`, `list` FROM `house_lists`");
	if (result) {
		do {
			House* house = g_game.map.houses.getHouse(result->getNumber<uint32_t>("house_id"));
			if (house) {
				house->setAccessList(result->getNumber<uint32_t>("listid"), result->getString("list"));
			}
		} while (result->next());
	}
	return true;
}

bool IOMapSerialize::saveHouseInfo()
{
	Database& db = Database::getInstance();

	DBTransaction transaction;
	if (!transaction.begin()) {
		return false;
	}

	if (!db.executeQuery("DELETE FROM `house_lists`")) {
		return false;
	}

	std::ostringstream query;
	for (auto& it : g_game.map.houses.getHouses()) {
		House* house = &it.second;
		query << "SELECT `id` FROM `houses` WHERE `id` = " << house->getId();
		DBResult_ptr result = db.storeQuery(query.str());
		if (result) {
			query.str(std::string());
			query << "UPDATE `houses` SET `owner` = " << house->getOwner() << ", `paid` = " << house->getPaidUntil() << ", `warnings` = " << house->getPayRentWarnings() << ", `name` = " << db.escapeString(house->getName()) << ", `town_id` = " << house->getTownId() << ", `rent` = " << house->getRent() << ", `size` = " << house->getTiles().size() << ", `beds` = " << house->getBedCount() << " WHERE `id` = " << house->getId();
		} else {
			query.str(std::string());
			query << "INSERT INTO `houses` (`id`, `owner`, `paid`, `warnings`, `name`, `town_id`, `rent`, `size`, `beds`) VALUES (" << house->getId() << ',' << house->getOwner() << ',' << house->getPaidUntil() << ',' << house->getPayRentWarnings() << ',' << db.escapeString(house->getName()) << ',' << house->getTownId() << ',' << house->getRent() << ',' << house->getTiles().size() << ',' << house->getBedCount() << ')';
		}

		db.executeQuery(query.str());
		query.str(std::string());
	}

	DBInsert stmt("INSERT INTO `house_lists` (`house_id` , `listid` , `list`) VALUES ");

	for (auto& it : g_game.map.houses.getHouses()) {
		House* house = &it.second;

		std::string listText;
		if (house->getAccessList(GUEST_LIST, listText) && !listText.empty()) {
			query << house->getId() << ',' << GUEST_LIST << ',' << db.escapeString(listText);
			if (!stmt.addRow(query)) {
				return false;
			}

			listText.clear();
		}

		if (house->getAccessList(SUBOWNER_LIST, listText) && !listText.empty()) {
			query << house->getId() << ',' << SUBOWNER_LIST << ',' << db.escapeString(listText);
			if (!stmt.addRow(query)) {
				return false;
			}

			listText.clear();
		}

		for (Door* door : house->getDoors()) {
			if (door->getAccessList(listText) && !listText.empty()) {
				query << house->getId() << ',' << door->getDoorId() << ',' << db.escapeString(listText);
				if (!stmt.addRow(query)) {
					return false;
				}

				listText.clear();
			}
		}
	}

	if (!stmt.execute()) {
		return false;
	}

	return transaction.commit();
}
