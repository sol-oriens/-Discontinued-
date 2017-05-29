// Consolidation
// ------
// Manages tasks such as building basic infrastructure in weakened or
// newly colonized systems to support Military or Colonization.
//
import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Budget;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Development;
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Systems;

from ABEM_data import NEBULA_FLAG;
from ABEM_data import CERULEAN_NEBULA_FLAG;
from ABEM_data import ECONOMIC_NEBULA_FLAG;
from ABEM_data import EMPTY_SPACE_NEBULA_FLAG;
from ABEM_data import METAPHASIC_NEBULA_FLAG;
from ABEM_data import METREON_NEBULA_FLAG;
from ABEM_data import MUTARA_NEBULA_FLAG;
from ABEM_data import RADIOACTIVE_NEBULA_FLAG;
from ABEM_data import TACHYON_NEBULA_FLAG;
from ABEM_data import TYPE_1_NEBULA_FLAG;

final class OrbitalOrder {
  BuildOrbital@ info;

  double expires = INFINITY;

  OrbitalOrder(BuildOrbital@ info) {
    @this.info = info;
  }

  void save(Consolidation& consolidation, SaveFile& file) {
  }

  void load(Consolidation& consolidation, SaveFile& file) {
  }
}

final class SystemCheck {
  Region@ region;
  OrbitalAI@ orbital;

  array<OrbitalOrder@> orders;

  double checkInTime = 0.0;
  bool isUnderAttack = false;

  SystemCheck(Region@ region) {
    @this.region = region;
    checkInTime = gameTime;
  }

  void save(Consolidation& consolidation, SaveFile& file) {
  }

  void load(Consolidation& consolidation, SaveFile& file) {
  }

  void tick(AI& ai, Consolidation& consolidation, double time) {
    isUnderAttack = region.ContestedMask & ai.mask != 0;

    /*if (isUnderAttack && isBuilding()) {
      //Cancel order
    }*/
    if (isBuilding()) {
      for (int i = 0, cnt = orders.length; i < cnt; ++i) {
        OrbitalOrder@ order = orders[i];
        if (order.info.completed) {
          //ai.print("order completed");
          @orbital = consolidation.orbitals.getInSystem(ai.defs.TradeOutpost, region);
          if (orbital !is null) {
            orders.remove(order);
            @order = null;
          }
        }
        else if (!order.info.started && order.expires < gameTime) {
          //ai.print("order expired, gameTime =" + gameTime);
          orders.remove(order);
          @order = null;
        }
        if (orbital !is null) {
          if(!orbital.obj.valid) {
            @orbital = null;
            orders.remove(order);
    				@order = null;
    			}
        }
      }
    }
  }

  void focusTick(AI& ai, Consolidation& consolidation, double time) {
  }

  void build(Construction& construction, const OrbitalModule@ module, double priority = 1.0, bool force = false, double delay = 600) {
    vec3d pos = region.position;
    vec2d offset = random2d(region.radius * 0.4, region.radius * 0.8);
    pos.x += offset.x;
    pos.z += offset.y;

    BuildOrbital@ info = construction.buildOrbital(module, pos, priority, force);
    OrbitalOrder@ order = OrbitalOrder(info);
    order.expires = gameTime + delay;
    orders.insertLast(order);
  }

  bool isBuilding() {
    if (orders.length > 0)
      return true;
    return false;
  }

  bool isBuildingOrbital(const OrbitalModule@ module) {
    for (uint i = 0, cnt = orders.length; i < cnt; ++i) {
      if (orders[i].info.module is module)
        return true;
    }
    return false;
  }
};

final class Consolidation : AIComponent {
  Budget@ budget;
  Construction@ construction;
  Orbitals@ orbitals;
	Systems@ systems;

  array<SystemCheck@> ownedSystems;
  array<SystemCheck@> outsideSystems;

  uint maxOrdersPerSys = 1;
  uint maxOrdersPerSysOutside = 1;
  uint maxOrdersTotal = 3;

  void create() {
    @budget = cast<Budget>(ai.budget);
    @construction = cast<Construction>(ai.construction);
		@orbitals = cast<Orbitals>(ai.orbitals);
		@systems = cast<Systems>(ai.systems);
	}

  void save(SaveFile& file) {
  }

  void load(SaveFile& file) {
  }

  void start() {
  }

  void tick(double time) override {
    SystemCheck@ sys;
    //Perform routine duties
    for (uint i = 0, cnt = ownedSystems.length; i < cnt; ++i) {
      @sys = ownedSystems[i];
      sys.tick(ai, this, time);
    }
    for (uint i = 0, cnt = outsideSystems.length; i < cnt; ++i) {
      @sys = outsideSystems[i];
      sys.tick(ai, this, time);
    }
  }

  void focusTick(double time) override {
    SystemCheck@ sys;
    //print("current total orders: " + getTotalOrders());
    //Find out which new systems need attention
    //ai.print("owned systems checked: " + ownedSystems.length);
    for(uint i = 0, cnt = systems.owned.length; i < cnt; ++i) {
      if (!isInCheck(systems.owned[i].obj, ownedSystems)) {
        @sys = SystemCheck(systems.owned[i].obj);
        //ai.print("adding owned system");
        ownedSystems.insertLast(sys);
      }
    }
    //Check if owned systems need anything
    for (uint i = 0, cnt = ownedSystems.length; i < cnt; ++i) {
      @sys = ownedSystems[i];
      //Check if any system was lost
      if (isMissing(sys.region, systems.owned)) {
        //ai.print("removing owned system");
        ownedSystems.remove(sys);
        @sys = null;
      }
      if (sys is null)
        break;
      //Don't do anything if the system is under attack
      if (!sys.isUnderAttack) {
        //Check if we already have something being built, we don't want to build too much
        //TODO: handle evaluation
        //ai.print("orders for owned system at index " + i + ": " + sys.orders.length);
        if (getTotalOrders() < maxOrdersTotal && sys.orders.length < maxOrdersPerSys) {
          //Find out if we need an outpost
          //TODO: handle Star Children & Evangelists
          if (!hasOutpost(sys.region) && shouldHaveOutpost(sys) && !sys.isBuildingOrbital(ai.defs.TradeOutpost)) {
            sys.build(construction, ai.defs.TradeOutpost);
            //ai.print("outpost ordered for owned system");
          }
        }
      }
      //Perform routine duties
      sys.focusTick(ai, this, time);
    }
    //Check if systems in tradable area need anything
    //ai.print("systems outside border: " + systems.outsideBorder.length);
    for (uint i = 0, cnt = outsideSystems.length; i < cnt; ++i) {
      @sys = outsideSystems[i];
      //Check if borders have changed
      if (isMissing(sys.region, systems.outsideBorder)) {
        //ai.print("removing outside system");
        outsideSystems.remove(sys);
        @sys = null;
      }
      //Check if we already have something being built, we don't want to build too much
      //TODO: handle evaluation
      if (sys is null)
        break;
      //ai.print("orders for outside system at index " + i + ": " + sys.orders.length);
      if (getTotalOrders() < maxOrdersTotal && sys.orders.length < maxOrdersPerSysOutside) {
        //Find out if we need an outpost
        //if (shouldHaveOutpost(sys) && !orbitals.haveInSystem(ai.defs.TradeOutpost, sys.region)) {
        if (!hasOutpost(sys.region) && shouldHaveOutpost(sys.region) && !sys.isBuildingOrbital(ai.defs.TradeOutpost)) {
          sys.build(construction, ai.defs.TradeOutpost);
          //ai.print("outpost ordered for outside system");
        }
      }
      //Perform routine duties
      sys.focusTick(ai, this, time);
    }
    //Find out which new systems need attention
    //ai.print("outside systems checked: " + outsideSystems.length);
    for(uint i = 0, cnt = systems.outsideBorder.length; i < cnt; ++i) {
      if (!isInCheck(systems.outsideBorder[i].obj, outsideSystems)) {
        @sys = SystemCheck(systems.outsideBorder[i].obj);
        //ai.print("adding outside system");
        outsideSystems.insertLast(sys);
      }
    }
  }

  bool isInCheck(Region& region, array<SystemCheck@> systems) {
    for (uint i = 0, cnt = systems.length; i < cnt; ++i) {
      if (systems[i].region is region)
        return true;
    }
    return false;
  }

  bool isMissing(Region& region, array<SystemAI@> systems) {
    for(uint i = 0, cnt = systems.length; i < cnt; ++i) {
      if (systems[i].obj is region)
        return false;
    }
    return true;
  }

  bool shouldHaveOutpost(SystemCheck& sys) {
    //Make sure we did not previously built an outpost here
    if (orbitals.haveInSystem(ai.defs.TradeOutpost, sys.region))
      return false;
    return true;
  }

  bool shouldHaveOutpost(Region& region) {
    //Make sure we did not previously built an outpost here
    if (orbitals.haveInSystem(ai.defs.TradeOutpost, region))
      return false;
    //Nebulae should have an outpost so we can expand our territory beyond them
    if (region.isNebula) {
      if (region.getSystemFlag(ai.empire, CERULEAN_NEBULA_FLAG)) {
        ai.print("identified a cerulean nebula");
      }
      else if (region.getSystemFlag(ai.empire, ECONOMIC_NEBULA_FLAG)) {
        ai.print("identified an economic nebula");
      }
      else if (region.getSystemFlag(ai.empire, EMPTY_SPACE_NEBULA_FLAG)) {
        ai.print("identified empty space");
      }
      else if (region.getSystemFlag(ai.empire, METAPHASIC_NEBULA_FLAG)) {
        ai.print("identified a metaphasic nebula");
      }
      else if (region.getSystemFlag(ai.empire, METREON_NEBULA_FLAG)) {
        ai.print("identified a metreon nebula");
        return false;
      }
      else if (region.getSystemFlag(ai.empire, MUTARA_NEBULA_FLAG)) {
        ai.print("identified a mutara nebula");
      }
      else if (region.getSystemFlag(ai.empire, RADIOACTIVE_NEBULA_FLAG)) {
        ai.print("identified a radioactive nebula");
        return false;
      }
      else if (region.getSystemFlag(ai.empire, TACHYON_NEBULA_FLAG)) {
        ai.print("identified a tachyon nebula");
      }
      else if (region.getSystemFlag(ai.empire, TYPE_1_NEBULA_FLAG)) {
        ai.print("identified a type 1 nebula");
      }
      return true;
    }
    return false;
  }

  bool hasOutpost(Region@ region) {
    return orbitals.haveInSystem(ai.defs.TradeOutpost, region);
  }

  uint getTotalOrders() {
    uint total = 0;
    for (uint i = 0, cnt = ownedSystems.length; i < cnt; ++i) {
      total += ownedSystems[i].orders.length;
    }
    for (uint i = 0, cnt = outsideSystems.length; i < cnt; ++i) {
      total += outsideSystems[i].orders.length;
    }
    return total;
  }
};

AIComponent@ createConsolidation() {
	return Consolidation();
}
