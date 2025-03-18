#ifndef _Parse_h_
#define _Parse_h_

#if FREEORION_BUILD_PARSE && __GNUC__
#   define FO_PARSE_API __attribute__((__visibility__("default")))
#else
#   define FO_PARSE_API
#endif

#include "../util/boost_fix.h"
#include <boost/filesystem/path.hpp>
#include <boost/uuid/uuid.hpp>

#include <array>
#include <map>
#include <memory>
#include <set>
#include <vector>
#include <unordered_map>

class BuildingType;
class FieldType;
class FleetPlan;
class ShipHull;
class MonsterFleetPlan;
class ShipPart;
struct ParsedShipDesign;
class Special;
class Species;
struct EncyclopediaArticle;
struct GameRule;
struct UnlockableItem;
class Policy;

class PythonParser;

namespace ValueRef {
    struct ValueRefBase;
    template <typename T>
    struct ValueRef;
}

namespace parse {

    /* T in techs<T> can only be TechManager::TechParseTuple.  This decouples
       Parse.h from Tech.h so that all parsers are not recompiled when Tech.h changes.*/
    template <typename T>
    FO_PARSE_API T techs(const PythonParser& parser, const boost::filesystem::path& path, bool& success);

}

#endif
