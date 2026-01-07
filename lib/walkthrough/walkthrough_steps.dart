enum TooltipPosition { above, below, center }

enum WalkthroughAction { swipeLeft, swipeRight, tap }

class WalkthroughStep {
  final String id;
  final String title;
  final String description;
  final TooltipPosition position;
  final bool requiresAction;
  final WalkthroughAction? requiredAction;
  final bool mobileOnly;
  final bool tabletOnly;

  const WalkthroughStep({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    this.requiresAction = false,
    this.requiredAction,
    this.mobileOnly = false,
    this.tabletOnly = false,
  });
}

const List<WalkthroughStep> walkthroughSteps = [
  // ============ COMMON STEPS (BOTH MOBILE & TABLET) ============
  WalkthroughStep(
    id: 'expression_area',
    title: 'Expression Display',
    description:
        'Your mathematical expressions appear here with proper formatting - fractions, roots, exponents and more!',
    position: TooltipPosition.below,
  ),
  WalkthroughStep(
    id: 'result_area',
    title: 'Live Results',
    description:
        'See your calculation results update in real-time as you type.',
    position: TooltipPosition.below,
  ),
  WalkthroughStep(
    id: 'ans_index',
    title: 'Cell Index & ANS',
    description:
        'Each cell has an index number. Use "ans" followed by an index to reference previous results. For example, "ans0" uses the result from cell 0.',
    position: TooltipPosition.below,
  ),
  WalkthroughStep(
    id: 'basic_keypad',
    title: 'Quick Access Keypad',
    description:
        'Tap the handle above to expand/collapse quick access numbers and operations.',
    position: TooltipPosition.above,
  ),
  WalkthroughStep(
    id: 'command_button',
    title: 'Command Button',
    description:
        'Tap ⌘ to create a new calculation cell. Each cell can have its own expression and result!',
    position: TooltipPosition.above,
  ),

  // ============ MOBILE ONLY STEPS ============
  WalkthroughStep(
    id: 'number_keypad',
    title: 'Number Pad',
    description: 'This is your main number pad with basic operations.',
    position: TooltipPosition.above,
    mobileOnly: true,
  ),
  WalkthroughStep(
    id: 'swipe_right_scientific',
    title: 'Swipe for Scientific Functions',
    description: 'Swipe RIGHT to access trigonometry, logarithms, and more!',
    position: TooltipPosition.above,
    requiresAction: true,
    requiredAction: WalkthroughAction.swipeRight,
    mobileOnly: true,
  ),
  WalkthroughStep(
    id: 'scientific_keypad',
    title: 'Scientific Functions',
    description: 'Access sin, cos, tan, logarithms, roots, and exponents here.',
    position: TooltipPosition.above,
    mobileOnly: true,
  ),
  WalkthroughStep(
    id: 'swipe_left_number',
    title: 'Go Back',
    description: 'Swipe LEFT to return to the number pad.',
    position: TooltipPosition.above,
    requiresAction: true,
    requiredAction: WalkthroughAction.swipeLeft,
    mobileOnly: true,
  ),
  WalkthroughStep(
    id: 'swipe_left_extras',
    title: 'More Functions',
    description: 'Swipe LEFT again for additional functions!',
    position: TooltipPosition.above,
    requiresAction: true,
    requiredAction: WalkthroughAction.swipeLeft,
    mobileOnly: true,
  ),
  WalkthroughStep(
    id: 'extras_keypad',
    title: 'Extra Functions',
    description:
        'Permutations, combinations, factorial, undo/redo, and settings are here.',
    position: TooltipPosition.above,
    mobileOnly: true,
  ),
  // NEW: Settings button step for mobile
  WalkthroughStep(
    id: 'settings_button',
    title: 'Settings',
    description:
        'Tap the gear icon \u2699 anytime to access settings. You can always restart this tutorial from there!',
    position: TooltipPosition.above,
    mobileOnly: true,
  ),
  WalkthroughStep(
    id: 'swipe_right_back',
    title: 'Navigate Back',
    description: 'Swipe RIGHT to return to previous keypads anytime.',
    position: TooltipPosition.above,
    requiresAction: true,
    requiredAction: WalkthroughAction.swipeRight,
    mobileOnly: true,
  ),

  // ============ TABLET ONLY STEPS ============
  WalkthroughStep(
    id: 'tablet_keypads_visible',
    title: 'Scientific & Number Pads',
    description:
        'On your wider screen, both the Scientific functions (left) and Number pad (right) are visible together!',
    position: TooltipPosition.above,
    tabletOnly: true,
  ),
  WalkthroughStep(
    id: 'tablet_swipe_left_extras',
    title: 'Swipe for More',
    description:
        'Swipe LEFT to reveal the Extras keypad with permutations, combinations, undo/redo, and settings.',
    position: TooltipPosition.above,
    requiresAction: true,
    requiredAction: WalkthroughAction.swipeLeft,
    tabletOnly: true,
  ),
  WalkthroughStep(
    id: 'tablet_extras_visible',
    title: 'Number Pad & Extras',
    description:
        'Now you can see the Number pad and Extra functions together. Access permutations, combinations, factorial, and more!',
    position: TooltipPosition.above,
    tabletOnly: true,
  ),
  WalkthroughStep(
    id: 'tablet_settings_button',
    title: 'Settings',
    description:
        'Tap the gear icon \u2699 anytime to access settings. You can always restart this tutorial from there!',
    position: TooltipPosition.above,
    tabletOnly: true,
  ),
  WalkthroughStep(
    id: 'tablet_swipe_right_back',
    title: 'Navigate Back',
    description:
        'Swipe RIGHT to return to Scientific and Number pads anytime.',
    position: TooltipPosition.above,
    requiresAction: true,
    requiredAction: WalkthroughAction.swipeRight,
    tabletOnly: true,
  ),

  // ============ COMMON FINAL STEP ============
  WalkthroughStep(
    id: 'complete',
    title: 'You\'re All Set!',
    description: 'You now know the basics. Enjoy calculating!',
    position: TooltipPosition.center,
  ),
];