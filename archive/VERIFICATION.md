# Lucy Game - Detailed Verification Guide

This guide provides step-by-step instructions to verify that the Lucy Game application is working correctly. Each section tests a specific component.

**Critical**: Open **DevTools (F12) → Console tab BEFORE opening index.html**

---

## Phase 1: JavaScript Execution & Console Output

### 1.1: Verify Entry Point Executes

1. **Open browser DevTools**
   - Press `F12` (or right-click → Inspect)
   - Go to **Console** tab
   - Ensure console is visible

2. **Open index.html**
   - In address bar, navigate to `file:///path/to/lucy_game/index.html`
   - OR serve with `python3 -m http.server` and visit `http://localhost:8000`

3. **Check initialization logs**
   - Look for these messages (in order):
     ```
     🚀 Lucy Game - Starting application...
     📍 Looking for canvas element: #game-canvas
     🎨 Initializing Paint canvas framework...
     🎮 Lucy Game - Initializing model...
     ✓ Model initialized - Grid: 160x100, pixel scale: 6
     ✓ Canvas interactive mode started!
     ```

4. **Check for errors**
   - No red error messages should appear
   - No "Cannot find module" or "404" errors
   - No "undefined" references

**Expected Result**: All initialization messages appear with no errors ✓

---

## Phase 2: Canvas Initialization

### 2.1: Visual Canvas Verification

1. **Look at the page**
   - You should see a **white/light gray canvas** roughly in the center
   - Canvas should have a **blue border** with rounded corners
   - Below the canvas should be **white space with purple gradient background**

2. **Check canvas dimensions**
   - Canvas should be **960 pixels wide × 620 pixels tall**
   - If canvas is too small or distorted, there's an initialization issue

3. **Inspect in DevTools**
   - In DevTools, go to **Elements** tab
   - Find the `<canvas id="game-canvas">` element
   - Verify attributes: `width="960" height="620"`

### 2.2: Console Canvas Output

1. **Check browser console**
   - Canvas initialization should have logged successfully
   - Look for messages indicating paint library loaded

2. **No render errors**
   - Initial empty grid should render without errors
   - Canvas should be interactive (move mouse over it)

**Expected Result**: White canvas appears, no errors in console ✓

---

## Phase 3: Event Handling & Input

### 3.1: Test Mouse Events

1. **Move mouse over canvas**
   - Open console
   - **Move mouse** over the canvas slowly
   - Check console for mouse position messages

   **Should see**: (intermittent, mouse may move too fast)
   ```
   (possibly no output if moving without clicking)
   ```

2. **Click on canvas**
   - **Click** once on the canvas
   - Check console for:
   ```
   🖱️ Mouse pressed
   ```

3. **Drag on canvas**
   - **Click and hold** on canvas
   - **Drag** slowly across canvas
   - Check console for messages like:
   ```
   🖱️ Mouse pressed
   ✏️ Drawing Sand at pixel (10, 15)
   ✏️ Drawing Sand at pixel (11, 15)
   ...
   ```

4. **Release mouse**
   - **Release** the mouse button
   - Check console for:
   ```
   🖱️ Mouse released
   ```

**Expected Result**: Mouse events log to console, no errors ✓

---

## Phase 4: Rendering & Visual Output

### 4.1: Draw Particles on Canvas

1. **Draw sand particles**
   - Click and drag on the **white canvas area**
   - You should see **golden/tan colored squares** appear where you drew
   - The color should be distinct from the white background

2. **Verify coordinates**
   - In console, you should see coordinates like:
   ```
   ✏️ Drawing Sand at pixel (42, 35)
   ✏️ Drawing Sand at pixel (43, 35)
   ```

3. **Brush size test**
   - Draw in one spot
   - You should see a **small cluster of squares** appear (default radius ~3 pixels)

4. **Color verification**
   - Sand: **Golden/Tan color** (RGB 218, 165, 32)
   - Particles should be visually distinct from white background

**Expected Result**: Colored squares appear on canvas when you draw ✓

---

## Phase 5: Keyboard Controls

### 5.1: Test Brush Switching

1. **Press 'S' key**
   - Look at console for:
   ```
   🟫 Sand brush selected
   ```

2. **Press 'W' key**
   - Draw on canvas
   - Particles should be **blue** (water)
   - Console shows:
   ```
   💧 Water brush selected
   ✏️ Drawing Water at pixel...
   ```

3. **Press 'X' key**
   - Draw on canvas
   - Particles should be **gray** (stone)
   - Console shows:
   ```
   🪨 Stone brush selected
   ```

4. **Press 'Z' key**
   - Draw on canvas
   - Should erase particles (set to air)
   - Console shows:
   ```
   🗑️ Eraser selected
   ✏️ Drawing Air at pixel...
   ```

**Expected Result**: All particle types render with correct colors, keyboard switches brush ✓

---

## Phase 6: Physics Simulation

### 6.1: Start Simulation

1. **Draw some sand on canvas**
   - Create a pile in the **middle or middle-lower area**

2. **Press Space key**
   - Console should show:
   ```
   ⏯️ Space pressed - Starting simulation
   ```

3. **Watch canvas**
   - Sand particles should **fall downward**
   - They should stack up at the bottom

4. **Watch console**
   - Every 10 steps, you should see:
   ```
   📊 Step: 10, Phase: 0
   📊 Step: 20, Phase: 0
   📊 Step: 30, Phase: 0
   ```

### 6.2: Water Physics

1. **Reset the grid**
   - Press **Enter** key
   - Console shows: `🔄 Reset pressed - Clearing grid`
   - Canvas should be white again

2. **Draw water**
   - Draw a pool of **blue** in middle-lower area

3. **Start simulation**
   - Press **Space**
   - Water should **spread horizontally** and **flow down**
   - Different behavior from sand!

### 6.3: Stone Physics

1. **Reset**
   - Press **Enter**

2. **Create a structure**
   - Draw **stone** (gray) in a shape
   - Draw **sand** above/beside it
   - Start simulation (Space)

3. **Observe interaction**
   - Sand should **pile on top of stone**
   - Sand should **not pass through stone**
   - Stone should **not move**

**Expected Result**: Different particle types behave differently under gravity ✓

---

## Phase 7: UI Display

### 7.1: Status Text

1. **Look at text below canvas**
   - Initial text shows:
   ```
   Step: 0 | Stopped | Brush: Sand | Keys: Space=Start, Enter=Reset, W=Water, S=Sand, X=Stone, Z=Eraser
   ```

2. **Press Space**
   - Text should change to:
   ```
   Step: XX | Running | Brush: Sand | ...
   ```

3. **Change brush**
   - Press 'W'
   - Text should update to:
   ```
   ... | Brush: Water | ...
   ```

4. **Watch step counter**
   - Every frame, step should increment (0, 1, 2, 3, ...)
   - Counter should increase steadily

**Expected Result**: UI text updates in real-time, reflects current state ✓

---

## Phase 8: Complete Integration Test

### 8.1: Full Workflow

Follow this complete sequence and verify all steps:

1. **✓ Page loads** (Phase 2)
   - Canvas appears, no errors
   - Console shows initialization messages

2. **✓ Draw sand** (Phase 4 & 5)
   - Click and drag on canvas
   - Golden/tan squares appear
   - Console logs coordinates

3. **✓ Switch to water** (Phase 5)
   - Press 'W'
   - Draw blue particles
   - Console shows brush change

4. **✓ Start simulation** (Phase 6)
   - Press Space
   - Particles move
   - Console shows step counter

5. **✓ Test stone** (Phase 6)
   - Press 'X'
   - Draw gray
   - Observe it blocks falling particles

6. **✓ Reset** (Phase 5)
   - Press Enter
   - Canvas clears (white)
   - Step counter resets to 0

### 8.2: Console Log Verification

Open DevTools → Console and look for these message patterns:

**Startup**:
```
🚀 Lucy Game - Starting application...
📍 Looking for canvas element: #game-canvas
🎨 Initializing Paint canvas framework...
🎮 Lucy Game - Initializing model...
✓ Model initialized - Grid: 160x100, pixel scale: 6
✓ Canvas interactive mode started!
```

**Interaction**:
```
🖱️ Mouse pressed
✏️ Drawing Sand at pixel (42, 35)
🖱️ Mouse released
🟫 Sand brush selected
```

**Simulation**:
```
⏯️ Space pressed - Starting simulation
📊 Step: 10, Phase: 0
📊 Step: 20, Phase: 0
🎨 Rendering 50 active cells
🔄 Reset pressed - Clearing grid
```

**Expected Result**: All above message patterns appear, no errors ✓

---

## Troubleshooting

### Issue: Canvas doesn't appear

**Check**:
1. Browser console for errors (red messages)
2. Network tab - any 404 errors loading assets?
3. Try opening with `python3 -m http.server` instead of file:// protocol

**Fix**:
```bash
rm -rf priv/javascript
gleam build --target javascript
node build.mjs
python3 -m http.server
# Visit http://localhost:8000
```

### Issue: No console output

**Check**:
1. Is DevTools → Console tab open?
2. Are you on the page with the game loaded?
3. Filter console - might be showing only warnings/errors

**Fix**:
1. Press F12 to open DevTools
2. Click **Console** tab
3. Make sure filter is set to show all messages
4. Reload page with F5

### Issue: Particles don't appear when drawing

**Check**:
1. Console shows drawing logs with coordinates?
2. Coordinates are within 0-160 (x) and 0-100 (y)?
3. Are you clicking on the white canvas area?

**Fix**:
1. Click in the **middle of the white canvas**
2. Check console for `✏️ Drawing Sand at pixel...` messages
3. If not appearing, canvas selector might be wrong

### Issue: Physics doesn't work (particles don't fall)

**Check**:
1. Did you press **Space** key?
2. Console shows `⏯️ Space pressed`?
3. Console shows `📊 Step: XX` messages?

**Fix**:
1. Verify Space key starts simulation (console should log)
2. If steps increment but particles don't move, there may be a rendering issue

### Issue: Wrong particle colors

**Check**:
1. Sand should be **golden/tan** (like sand)
2. Water should be **blue**
3. Stone should be **gray**

**Fix**:
1. Colors are defined in renderer.gleam
2. If colors are wrong, check HTML canvas color rendering
3. Try a different browser to rule out display issues

---

## Performance Notes

- Canvas should update **smoothly** at ~60 FPS
- Drawing/moving mouse should feel **responsive** (< 100ms latency)
- Console logs appear **instantly** when events occur
- Physics steps should happen **every frame** when running

---

## Final Verification Checklist

- [ ] Canvas appears with white background
- [ ] Drawing sand produces golden/tan particles
- [ ] Brush switching (S/W/X/Z) changes particle color
- [ ] Pressing Space starts simulation
- [ ] Particles fall under gravity
- [ ] Water spreads differently than sand
- [ ] Stone blocks falling particles
- [ ] Reset (Enter) clears the grid
- [ ] Console shows all expected messages
- [ ] No red error messages in console
- [ ] UI text updates in real-time
- [ ] Step counter increments

**If all items are checked**: ✅ Application is fully functional!

If any item fails, check the Troubleshooting section above.
