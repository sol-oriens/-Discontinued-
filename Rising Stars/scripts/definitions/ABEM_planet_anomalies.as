import hooks;
import generic_hooks;
import anomalies;
from anomalies import IAnomalyHook, AnomalyHook;

#section server
import objects.Anomaly;
#section all

class AddPlanetAnomaly : BonusEffect {
  Document doc("Add a planet anomaly on the target planet.");
	Argument type(AT_Anomaly, "distributed", doc="Type of anomaly to spawn. Defaults to randomized.");
	Argument start_scanned(AT_Boolean, "False", doc="Whether the anomaly starts out scanned by the empire that triggered this.");

	const AnomalyType@ anomType;

	bool instantiate() {
		if(!type.str.equals_nocase("distributed")) {
			@anomType = getAnomalyType(type.str);
			if(anomType is null) {
				error(" Error: Could not find anomaly type: '"+escape(type.str)+"'");
				return false;
			}
		}
		return BonusEffect::instantiate();
	}

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(obj is null)
			return;
    Planet@ pl = cast<Planet@>(obj);
    if (pl is null)
      return;

		const AnomalyType@ type = anomType;
		if(type is null) {
			do {
				@type = getDistributedAnomalyType(getAnomalyTypes(AK_TerrestrialAnomaly));
			}
			while(type.unique);
		}

		Anomaly@ anomaly = createPlanetAnomaly(pl, type.id);
		if(start_scanned.boolean && emp !is null)
			anomaly.addProgress(emp, 10000000000.f);
	}
#section all
};

//TriggerOnPlanet(<Hook>(...))
// Run <Hook> as a single-time effect hook on the planet containing this anomaly.
class TriggerOnPlanet : AnomalyHook {
	Document doc("Runs another type of hook on the target when activated.");
	Argument hookID("Hook", AT_Hook, "planet_effects::GenericEffect", doc="Hook to run.");
	GenericEffect@ hook;

	bool instantiate() override {
		@hook = cast<GenericEffect>(parseHook(hookID.str, "planet_effects::"));
		if(hook is null) {
			error("GenericEffect(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return AnomalyHook::instantiate();
	}

#section server
	void choose(Anomaly@ obj, Empire@ emp, Targets@ targets) const override {
		if (obj.planet is null)
			return;
		hook.enable(obj.planet, null);
	}
#section all
};
