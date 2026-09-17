-- Lid switch handling (Hyprland-native, no acpid/logind needed for the action).
-- Requires systemd-logind to ignore the lid (see /etc/systemd/logind.conf.d/),
-- otherwise logind suspends before these binds can act.
--
-- Lid closed ("switch:on"): if an external monitor is connected, disable the
-- internal panel so Hyprland falls over to it ("clamshell mode"). If docked
-- nowhere, suspend instead.
-- Lid opened ("switch:off"): reload the config to restore the internal panel.
-- NOTE: re-enabling via hl.monitor({ ..., disabled = false }) does NOT take
-- effect at runtime on Hyprland 0.56 (verified) - only a reload re-applies
-- config/monitors.lua, which defines eDP-1 as enabled.
--
-- NOTE: keep this file required AFTER config/monitors in hyprland.lua -
-- switch binds registered before the monitor definitions are unreliable.

-- Lid closed
hl.bind("switch:on:Lid Switch", function()
	local external = false
	for _, mon in ipairs(hl.get_monitors()) do
		if mon.name ~= MONITOR1 then
			external = true
			break
		end
	end
	if external then
		hl.monitor({ output = MONITOR1, disabled = true })
	else
		hl.dispatch(hl.dsp.exec_cmd("systemctl suspend"))
	end
end, { locked = true })

-- Lid opened
hl.bind("switch:off:Lid Switch", function()
	hl.dispatch(hl.dsp.exec_cmd("hyprctl reload"))
end, { locked = true })
