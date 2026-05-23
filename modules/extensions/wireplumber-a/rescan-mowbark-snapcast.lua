lutils = require ("linking-utils")
log = Log.open_topic ("s-linking")

SimpleEventHook {
  name = "linking/rescan-mowbark-snapcast",
  after = "linking/rescan",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "rescan-for-linking" },
    },
  },
  execute = function (event)
    local source = event:get_source ()
    local om = source:call ("get-object-manager", "session-item")

    log:info ("rescanning for mowbark-snapcast...")

    for si in om:iterate {
      type = "SiLinkable",
      Constraint { "item.node.type", "=", "device" },
      Constraint { "application.name", "=", "Snapcast" },
    } do
      local si_props = si.properties
      log:info ("mowbark-snapcast handling " .. si_props ["node.name"])
      if si_props ["target.object"] ~= nil then
        local target = om:lookup {
          type = "SiLinkable",
          Constraint { "node.name", "=", si_props ["target.object"] },
        }
        if target and lutils.canLink (si_props, target) then
          log:info ("...found " .. si_props ["target.object"])
          local event = source:call ("create-event", "select-target", si, nil)
          event:set_data ("target", target)
          EventDispatcher.push_event (event)
        end
      end
    end
  end
}:register()
