import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'default_config.dart';
import 'sdui_provider.dart';
import 'sdui_types.dart';

/// Editable copy for the kitchen details screen.
///
/// Same boundary as [LoginCopy]: the server may change words and section
/// headings, never behaviour. The dish list, cart maths and ratings stay native,
/// because those depend on live provider data that has no JSON representation.
///
/// Reads from the `kitchen_details` spec:
///   * `section` nodes supply section headings (matched to native sections by
///     the `id` an admin gives them: `section_menu`, `section_reviews`).
///   * The first `dish_row` node's `description` supplies the empty-state copy,
///     which is how an admin rewords "no dishes yet" without a release.
class KitchenDetailsCopy {
  const KitchenDetailsCopy({this.menuHeading, this.reviewsHeading, this.emptyState});

  final String? menuHeading;
  final String? reviewsHeading;
  final String? emptyState;

  static const KitchenDetailsCopy empty = KitchenDetailsCopy();

  static const String defaultMenuHeading = 'Menu';
  static const String defaultReviewsHeading = 'Reviews';
  static const String defaultEmptyState = 'No dishes in this section yet.';

  static KitchenDetailsCopy resolve(BuildContext context) {
    try {
      final sdui = context.read<SduiProvider>();
      final spec = sdui.specFor(SduiKeys.kitchenDetails);
      String? menu;
      String? reviews;
      String? empty;

      for (final node in spec.root.children) {
        switch (node.type) {
          case SduiNodeType.section:
            if (node.id == 'section_menu' && node.title != null) {
              menu = node.title;
            } else if (node.id == 'section_reviews' && node.title != null) {
              reviews = node.title;
            }
          case SduiNodeType.text:
            if (empty == null && node.text.trim().isNotEmpty) {
              empty = node.text;
            }
          default:
            break;
        }
      }

      return KitchenDetailsCopy(
        menuHeading: menu,
        reviewsHeading: reviews,
        emptyState: empty,
      );
    } catch (_) {
      return KitchenDetailsCopy.empty;
    }
  }

  String get menu => menuHeading ?? defaultMenuHeading;
  String get reviews => reviewsHeading ?? defaultReviewsHeading;
  String get emptyMessage => emptyState ?? defaultEmptyState;
}