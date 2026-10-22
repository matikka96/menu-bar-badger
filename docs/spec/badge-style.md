# Badge style

One global setting, `badgeStyle`, with three values. A change applies to all items at once.

## Red badge (`"redBadge"`, default)

- No text next to the icon. A red capsule with white text shows on the top-right corner of the icon.
- The icon keeps its full size with a badge. As a Dock badge does, the capsule extends 5 pt past the right
  edge of the icon and 2 pt past its top edge, so that it covers less of the icon.
- The capsule: the system red colour; the text in an 8 pt bold system font; a height of the text plus 4 pt;
  a width of the text plus 4 pt, but never narrower than its height, so a single digit gives a circle.
- **Label rules**, in this order:
  1. A **count above 99** shows "99+". A count is a text that starts with a digit, contains only digits and
     grouping marks (comma, period, space, no-break space, narrow no-break space, apostrophe), and can end
     with "+". "Above 99" means more than two digits after the leading zeros are removed. Examples that give
     "99+": "100", "123", "999+", "1,234", "1 234", a number with 20 digits.
  2. Else a text whose capsule is at most 22 pt wide shows as it is. Examples: "1", "99", "007", "9+",
     "99+", "1.5", "new", "•••".
  3. Else the label is one dot, "•". Examples: "hello", "1a2b", "+1234", ",1234".

## Number (`"number"`)

The badge text shows as plain text to the right of the icon. Any text shows in full, also a text that is
not a number ("new", "•").

## Icon only (`"iconOnly"`)

- Only the icon. No text and no capsule.
- The model still has the badge: the Apps tab shows "3 new", and VoiceOver reads it.
- Icon only turns off the [alert](alert.md) and the [arrow](arrow.md). The settings window disables their
  switches and shows the hint "Doesn't apply to Icon only."
- The [nothing-new modes](visibility.md) and "Hide while the app isn't running" still work. Example: Icon
  only with Hide gives an icon that shows only while the app has a badge.

## Menu bar preview

The setup screen shows the effect of the style and the icon mode at the top of its Preferences section
([accessibility.md](accessibility.md#setup-screen)).

- A mock menu bar strip in the system bar material over a neutral grey background, so that the item has
  the most visual weight: the menu titles "Finder" (bold), "File", "Edit" and "View" at the left, in the
  secondary colour, and the Mail item, a Wi-Fi symbol, a battery symbol and the clock
  at the right.
- The strip has the height of the menu bar on the main screen, so the item has the same size relative to the
  strip as in the real menu bar. While the menu bar hides itself, the strip is 31 pt high.
- The Mail item uses the icon of `com.apple.mail` in the icon mode of the "Icon" row, with the badge "3". If Mail is not
  installed, the item uses the default symbol of an item.
- The item draws with the same code as a real item (`ItemFace`: `ItemIcons`, `RedBadgeView` and the rules
  above). Number shows "3" to the right of the icon, Red badge shows the capsule with "3", and Icon only
  shows only the icon.
- A change of the style or of the icon mode changes the preview at once.
- For VoiceOver, the preview is one image with the label "Menu bar preview, ‹style› style: Mail, 3 new".
- The caption under the preview: "Preview with Mail as an example."

## Count parser

The arrow uses the same parser (see [arrow.md](arrow.md)). It reads a count as a whole number: it removes
the grouping marks and a trailing "+". A text that is not a count gives no number.

## Acceptance criteria

- Red badge: "99" gives "99", "123" gives "99+", "new" gives "new", "hello" gives "•", and each label gives a
  different image.
- A change of the style changes all items at once, with no relaunch.
- A change of the style on the setup screen changes the menu bar preview at once, and the General tab shows
  the same style after Done.
- Icon only with Hide: an empty badge hides the item; a badge shows it with no text and no capsule.
- Unit tests in `BadgerCore`: all the label examples above, and the count parser ("1,234" gives 1234,
  "99+" gives 99, "•" gives no number).
