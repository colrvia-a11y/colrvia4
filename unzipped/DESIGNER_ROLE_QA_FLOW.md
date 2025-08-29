# Designer Role Fix Pack - Manual QA Flow

## Quick Manual Testing Checklist

### 1. Canonical Role Order (Light → Dark)
**Expected Order**: Trim, Whisper, Bridge(Lighter), Main(Lighter), Main, Main(Deeper), Bridge(Deeper), Accent, Deep Accent

**Test Steps**:
1. Open Roller screen
2. Switch to Designer harmony mode
3. Open Tools → Style → Designer mode
4. Verify role labels appear in correct order from top to bottom:
   - Top stripe = Trim (lightest)
   - Bottom stripe = Deep Accent (darkest)
5. Roll palette multiple times - order should remain consistent

**Pass Criteria**: ✅ Role labels always appear in canonical light-to-dark order

### 2. Auto-Resize When Roles Change
**Test Steps**:
1. Start in Designer mode with default 5-stripe palette
2. Open Tools → Style → Designer mode
3. Select specific roles (e.g., only Trim, Main, Accent)
4. Verify palette automatically resizes to 3 stripes
5. Add more roles - verify palette expands accordingly
6. Remove roles - verify palette shrinks safely

**Pass Criteria**: 
- ✅ Palette size automatically matches number of selected roles
- ✅ No crashes when resizing
- ✅ Locked colors preserved when possible during resize

### 3. Designer Algorithm Restored
**Test Steps**:
1. Generate multiple Designer palettes (roll 10+ times)
2. Verify improved color relationships:
   - Adjacent colors have good LRV spacing (visually distinct lightness)
   - Colors flow harmoniously from light to dark
   - No "all similar" or "all analogous" palettes
   - Warm/cool balance across the palette

**Pass Criteria**: ✅ Palettes show better value spacing and undertone variety vs. random selection

### 4. No Duplicates Within Palette
**Test Steps**:
1. Roll palettes in all harmony modes (Neutral, Analogous, etc.)
2. Examine each generated palette
3. Verify no identical paints appear twice in same palette
4. Test with locked colors - verify no duplicates introduced
5. Expand to 9-stripe palette - verify uniqueness maintained

**Pass Criteria**: ✅ Every paint in a palette is unique by brand + line + SKU

### 5. Non-Designer Modes Unchanged
**Test Steps**:
1. Test Neutral, Analogous, Complementary, Triad modes
2. Verify they still generate varied, randomized palettes
3. Confirm Designer-specific rules don't affect other modes
4. Check performance - no significant slowdowns

**Pass Criteria**: ✅ Other harmony modes work exactly as before

### 6. Lock/Unlock Behavior
**Test Steps**:
1. In Designer mode, lock stripe in middle position
2. Roll palette - verify locked paint stays in canonical position
3. Change roles - verify locked paint maintains role if possible
4. Test edge cases: lock paint that doesn't fit new role lineup

**Pass Criteria**: ✅ Locked paints preserved with role continuity when feasible

### 7. Performance & Memory
**Test Steps**:
1. Swipe through 20+ palette pages rapidly
2. Change between harmony modes frequently
3. Resize palettes from 1→9 stripes multiple times
4. Monitor for memory leaks or performance degradation

**Pass Criteria**: ✅ Smooth performance, no memory issues, responsive UI

## Expected Behavior Summary

### Before Fix:
- Designer roles in inconsistent order
- Manual palette sizing only
- "All-analogous" Designer palettes common
- Possible duplicates in palettes

### After Fix:
- ✅ Canonical role order (Trim→Whisper→...→Deep Accent)
- ✅ Auto-resize palette = selected roles count
- ✅ Designer algorithm with LRV spacing + undertone balance
- ✅ Guaranteed uniqueness across all harmony modes
- ✅ Non-Designer modes unchanged

## Critical Test Cases

### Edge Cases to Verify:
1. **Empty role selection** - should fall back to default size
2. **Single role selection** - should create 1-stripe palette
3. **All 9 roles selected** - should create full 9-stripe palette
4. **Rapid role changes** - should handle state transitions cleanly
5. **Lock + resize conflicts** - should resolve gracefully

### Performance Benchmarks:
- **Palette generation**: < 200ms for 9-stripe Designer palette
- **Role change + resize**: < 100ms transition
- **Page swipe response**: < 50ms to show new palette
- **Memory usage**: Stable during extended use

## Error Conditions

### Should Handle Gracefully:
- Insufficient paint data for Designer constraints
- Network interruptions during palette generation
- Rapid user interactions (double-taps, quick swipes)
- State restoration after app background/foreground

### Never Should Happen:
- ❌ Crash on role selection changes
- ❌ Duplicate paints in same palette
- ❌ Designer roles in wrong order
- ❌ Palette size mismatch with selected roles