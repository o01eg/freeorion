
# For inclusion in a scope macro for an upgrade increase to a Max type meter (MaxCapacity or MaxSecondaryStat), and that scope
# should have already limited scope to ships owned by an empire
# In most cases the substitution provided for @1@ may simply be "CurrentContent" (without the quote marks) but
# if providing an explicit tech name then include quotes with the substitution,
# i.e., either use
# SHIP_PART_UPGRADE_RESUPPLY_CHECK("SOME_TECH")
# or
# SHIP_PART_UPGRADE_RESUPPLY_CHECK(CurrentContent)
def SHIP_PART_UPGRADE_RESUPPLY_CHECK(tech_name: str):
    return None


