# Badge style

One global setting, `badgeStyle`, with three values. A change applies to all items at once.

## Number (`"number"`, default)

The badge text shows as plain text to the right of the icon. Any text shows in full, also a text that is
not a number ("new", "•").

## Red badge (`"redBadge"`)

- No text next to the icon. A red capsule with white text shows on the top-right corner of the icon.
- With a badge, the icon shrinks a little so that the capsule fits in the square of the icon. With no
  badge, the plain icon shows at full size.
- The capsule: the system red colour; the text in a 6.5 pt bold system font, so that "new" fits; a height of the text plus
  4 pt; a width of the text plus 3 pt, but never narrower than its height, so a single digit gives a circle.
- **Label rules**, in this order:
  1. A **count above 99** shows "99+". A count is a text that starts with a digit, contains only digits and
     grouping marks (comma, period, space, no-break space, narrow no-break space, apostrophe), and can end
     with "+". "Above 99" means more than two digits after the leading zeros are removed. Examples that give
     "99+": "100", "123", "999+", "1,234", "1 234", a number with 20 digits.
  2. Else a text whose capsule fits the width of the icon shows as it is. Examples: "1", "99", "007", "9+",
     "99+", "1.5", "new", "•••".
  3. Else the label is one dot, "•". Examples: "hello", "1a2b", "+1234", ",1234".

## Icon only (`"iconOnly"`)

- Only the icon. No text and no capsule.
- The model still has the badge: the Apps tab shows "3 new", and VoiceOver reads it.
- Icon only turns off the [alert](alert.md) and the [arrow](arrow.md). The settings window disables their
  switches and shows the hint "Doesn't apply to Icon only."
- The [nothing-new modes](visibility.md) and "Hide while the app isn't running" still work. Example: Icon
  only with Hide gives an icon that shows only while the app has a badge.

## Count parser

The arrow uses the same parser (see [arrow.md](arrow.md)). It reads a count as a whole number: it removes
the grouping marks and a trailing "+". A text that is not a count gives no number.

## Acceptance criteria

- Red badge: "99" gives "99", "123" gives "99+", "new" gives "new", "hello" gives "•", and each label gives a
  different image.
- A change of the style changes all items at once, with no relaunch.
- Icon only with Hide: an empty badge hides the item; a badge shows it with no text and no capsule.
- Unit tests in `BadgerCore`: all the label examples above, and the count parser ("1,234" gives 1234,
  "99+" gives 99, "•" gives no number).
