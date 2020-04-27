-- madseq
-- a sequencer based on the sequencer module in Aalto and Kaivo
--
-- note pattern can be programmed with grid
-- hold K2 to program gate pattern
--
-- E1 controls pulse width
-- E2 controls gate delay (hold K2 for fine control)
-- E3 controls cv delay (hold K2 for fine control)
--
-- K3 randomizes notes
-- K2 + K3 randomizes gates
--
-- crow input 1 controls pattern length (-5v to 5v)
-- crow input 2 controls offset into pattern (-5v to 5v)
--
-- crow output 1 is a gate (8v)
-- crow output 2 is a delayed gate (8v)
-- crow output 3 is a note cv
-- crow output 4 is a delayed note cv

local MusicUtil = require "musicutil"
local util = require "util"
local UI = require "ui"

-- range = 12
-- glide = 0
MAX_STEPS = 16
ENABLED_BRIGHTNESS = 10
DISABLED_BRIGHTNESS = 5
SHIFT_KEY = 2

local g
local offset
local step
local steps
local notes
local gates
local shift
local update_clock
local width
local division
local scale_name
local scale
local cv_delay
local gate_delay
local width_dial
local cv_delay_dial
local gate_delay_dial

function init()
  g = grid.connect()
  g.key = grid_key

  offset = 0
  step = 1
  steps = MAX_STEPS
  notes = {}
  gates = {}
  for i = 1,steps do
    notes[i] = 1
    gates[i] = true
  end

  cv_delay = 0
  gate_delay = 0
  shift = 0
  width = 0.5
  division = 1/4
  scale_name = "aeolian"
  scale = MusicUtil.generate_scale(0, scale_name)

  update_clock = clock.run(update)

  crow.input[1].mode("stream", 0.01)
  crow.input[1].stream = update_steps

  crow.input[2].mode("stream", 0.01)
  crow.input[2].stream = update_offset

  width_dial = UI.Dial.new(0, 0, 40, width, 0.01, 0.99, 0.01)
  gate_delay_dial = UI.Dial.new(40, 0, 40, gate_delay, 0, 8, 0.1)
  cv_delay_dial = UI.Dial.new(80, 0, 40, cv_delay, 0, 8, 0.1)

  redraw()
  grid_redraw()
end

function key(n, z)
  if n == SHIFT_KEY then
    shift = z
  elseif n == 3 and z == 1 then
    if shift == 1 then
      randomize_gates()
    else
      randomize_notes()
    end
    grid_redraw()
  end
end

function randomize_notes()
  for i = 1,MAX_STEPS do
    notes[i] = math.random(8)
  end
end

function randomize_gates()
  for i = 1,MAX_STEPS do
    gates[i] = math.random(2) == 2
  end
end

function enc(n, d)
  local inc = shift == 1 and 0.1 or 0.5
  if n == 1 then
    width = util.clamp(width + d * 0.01, 0.01, 0.99)
    width_dial:set_value(width)
  elseif n == 2 then
    gate_delay = util.clamp(gate_delay + d * inc, 0, 8)
    gate_delay_dial:set_value(gate_delay)
  elseif n == 3 then
    cv_delay = util.clamp(cv_delay + d * inc, 0, 8)
    cv_delay_dial:set_value(cv_delay)
  end
  redraw()
end

function grid_key(x, y, z)
  if z ~= 1 then
    return
  end

  if shift == 0 then
    notes[x] = grid_to_note(y)
  else
    gates[x] = not gates[x]
  end

  grid_redraw()
end

function update_steps(v)
  steps = util.round(util.linlin(-5, 5, 1, MAX_STEPS, v), 1)
end

function update_offset(v)
  offset = util.round(util.linlin(-5, 5, 0, MAX_STEPS - 1, v), 1)
end

function update()
  while true do
    local i = get_current_step()

    if gates[i] then
      crow_gate()
    end

    volts = scale[notes[i]] / 12
    crow_cv(volts)

    grid_redraw()

    step = step + 1

    if step > steps then
      step = 1
    end

    clock.sync(division)
  end
end

function get_current_step()
  return ((offset + step - 1) % MAX_STEPS) + 1
end

function crow_gate()
  pulse_output(1)
  clock.run(function()
    local s = clock.get_beat_sec()
    clock.sleep(s * division * gate_delay)
    pulse_output(2)
  end)
end

function pulse_output(i)
  clock.run(function()
    crow.output[i].volts = 8
    local s = clock.get_beat_sec()
    clock.sleep(s * division * width)
    crow.output[i].volts = 0
  end)
end

function crow_cv(volts)
  crow.output[3].volts = volts
  clock.run(function()
    local s = clock.get_beat_sec()
    clock.sleep(s * division * cv_delay)
    crow.output[4].volts = volts
  end)
end

function redraw()
  screen.clear()

  width_dial:redraw()
  gate_delay_dial:redraw()
  cv_delay_dial:redraw()

  screen.update()
end

function grid_redraw()
  g:all(0)

  for i = 1,MAX_STEPS do
    grid_redraw_step(i)
  end

  g:refresh()
end

function grid_redraw_step(i)
  local s = get_current_step()
  local a = i == s and 2 or 0
  local b = gates[i] and ENABLED_BRIGHTNESS or DISABLED_BRIGHTNESS
  for n = 1,notes[i] do
    g:led(i, note_to_grid(n), b + a)
  end
end

function grid_to_note(y)
  return 9 - y
end

note_to_grid = grid_to_note
