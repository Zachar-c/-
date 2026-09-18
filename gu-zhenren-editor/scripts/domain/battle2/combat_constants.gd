class_name Battle2Constants
extends RefCounted


# Spec-v4 phase-5 (P0.2): single owner for the battle2 vocabulary shared by
# turn_engine / action_resolver / body_rules. Duplicated constants drifted
# exactly like SERVICE_USE_FLAG_PREFIX did in phase-2 - one owner only.
# Pure constants; keep this file free of any code (the zero-dice token audit
# scans the battle2 sources).


# §12.3/§13.1: the four universal basic actions, each 1 thought per round.
const BASIC_ACTIONS := ["move", "strike", "dodge", "grapple"]

# §13.3: four distance bands, outermost first by index.
const DISTANCES := ["far", "medium", "close", "touch"]
const DISTANCE_TOUCH := "touch"
const DISTANCE_CLOSE := "close"
const DISTANCE_MEDIUM := "medium"
const DISTANCE_FAR := "far"

# §13.4: legal disengage reactions (grapple, intercept gu, or an attack
# explicitly declared as a disengage reaction - ordinary strike is not one).
const DISENGAGE_REACTIONS := ["grapple", "intercept"]
