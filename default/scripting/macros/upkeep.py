from focs._conditions import EmpireHasAdoptedPolicy, IsSource
from focs._sources import Source
from focs._value_refs import (
    SpeciesColoniesOwned,
    StatisticIf,
)

COLONY_UPKEEP_MULTIPLICATOR = 1 + 0.06 * SpeciesColoniesOwned(empire=Source.Owner)

COLONIZATION_POLICY_MULTIPLIER = (
    1
    - (StatisticIf(float, condition=IsSource & EmpireHasAdoptedPolicy(empire=Source.Owner, name="PLC_COLONIZATION")))
    / 3
    + (StatisticIf(float, condition=IsSource & EmpireHasAdoptedPolicy(empire=Source.Owner, name="PLC_CENTRALIZATION")))
    / 3
)


def DESIGN_SIMPLICITY_COMPLEXITY_FACTOR_FOR_ARG1_VREF_STATIC(arg: int) -> float:
    if arg > 4:
        return 1.0
    elif arg > 3:
        return 0.95
    elif arg > 2:
        return 0.9
    else:
        return 0.8
