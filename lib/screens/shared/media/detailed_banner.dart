import 'package:async/async.dart';
import 'package:fladder/util/item_base_model/play_item_helpers.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/models/settings/home_settings_model.dart';
import 'package:fladder/screens/details_screens/components/overview_header.dart';
import 'package:fladder/screens/shared/media/components/media_play_button.dart';
import 'package:fladder/screens/shared/media/poster_row.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/fladder_image.dart';
import 'package:fladder/util/focus_provider.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/widgets/shared/custom_shader_mask.dart';
import 'package:fladder/widgets/shared/ensure_visible.dart';

class DetailedBanner extends ConsumerStatefulWidget {
  final List<ItemBaseModel> items;
  final Function(ItemBaseModel selected) onSelect;
  final HomeCarouselSettings carouselType;

  const DetailedBanner({
    required this.items,
    required this.onSelect,
    required this.carouselType,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DetailedBannerState();
}

class _DetailedBannerState extends ConsumerState<DetailedBanner> {
  late ValueNotifier<ItemBaseModel> selectedItem = ValueNotifier(widget.items.first);

  late final RestartableTimer timer = RestartableTimer(const Duration(seconds: 8), () => nextSlide());

  @override
  void initState() {
    super.initState();
    widget.onSelect(selectedItem.value);
    timer.reset();
  }

  @override
  void didUpdateWidget(covariant DetailedBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.items.isEmpty) {
      return;
    }

    if (oldWidget.items != widget.items && !widget.items.contains(selectedItem.value)) {
      selectedItem.value = widget.items.first;
      widget.onSelect(selectedItem.value);
    }

    timer.reset();
  }

  @override
  void dispose() {
    timer.cancel();
    selectedItem.dispose();
    super.dispose();
  }

  void nextSlide() {
    if (!mounted || widget.items.isEmpty) {
      return;
    }

    final currentIndex = widget.items.indexWhere((item) => item.id == selectedItem.value.id);
    final nextIndex = currentIndex == -1 || currentIndex >= widget.items.length - 1 ? 0 : currentIndex + 1;
    final nextItem = widget.items[nextIndex];

    selectedItem.value = nextItem;
    widget.onSelect(nextItem);
    timer.reset();

    // Preload next next backdrop
    final nextNextIndex = nextIndex == widget.items.length - 1 ? 0 : nextIndex + 1;
    final nextNextItem = widget.items[nextNextIndex];
    final nextBackdrop = nextNextItem.images?.backDrop?.firstOrNull ?? nextNextItem.images?.primary;
    if (nextBackdrop != null) {
      precacheImage(nextBackdrop.imageProvider, context);
    }
    final nextLogo = nextNextItem.images?.logo;
    if (nextLogo != null) {
      precacheImage(nextLogo.imageProvider, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = AdaptiveLayout.viewSizeOf(context) <= ViewSize.phone;
    final phoneOffsetHeight = isPhone ? MediaQuery.paddingOf(context).top + 80 : 0.0;
    final bottomImagePadding = MediaQuery.sizeOf(context).height * 0.25;

    final double maxHeight = (AdaptiveLayout.viewSizeOf(context) == ViewSize.phone
            ? MediaQuery.sizeOf(context).height * 0.75
            : MediaQuery.sizeOf(context).height * 0.9)
        .clamp(20, 1000);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomImagePadding),
            child: Align(
              alignment: Alignment.topLeft,
              child: ExcludeFocus(
                child: Transform.translate(
                  offset: Offset(0, -phoneOffsetHeight),
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    alignment: Alignment.topLeft,
                    child: SizedBox.expand(
                      child: CustomShaderMask(
                        child: ValueListenableBuilder(
                          valueListenable: selectedItem,
                          builder: (context, value, child) => FocusButton(
                            onTap: () => value.navigateTo(context),
                            visualizeFocus: false,
                            child: FladderImage(
                              image: value.images?.backDrop?.firstOrNull ?? value.images?.primary,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: double.infinity,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(height: 32),
              Expanded(
                child: ExcludeFocus(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 4),
                    child: FractionallySizedBox(
                      widthFactor: AdaptiveLayout.viewSizeOf(context) <= ViewSize.phone ? 1.0 : 0.55,
                      alignment: Alignment.bottomLeft,
                      child: ValueListenableBuilder(
                        valueListenable: selectedItem,
                        builder: (context, value, child) => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: OverviewHeader(
                                name: value.parentBaseModel.name,
                                subTitle: value.label(context.localized),
                                image: value.getPosters,
                                mainButton: Wrap(
                                  alignment: WrapAlignment.start,
                                  spacing: 12,
                                  children: [
                                    MediaPlayButton(
                                      item: value.copyWith(name: ''),
                                      onPressed: (restart) {
                                        value.play(context, ref);
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => value.navigateTo(context),
                                      icon: const Icon(Icons.info_outline),
                                      label: Text(context.localized.info),
                                    ),
                                  ],
                                ),
                                logoAlignment: Alignment.bottomLeft,
                                summary: Text(
                                  value.overview.summary,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: AdaptiveLayout.viewSizeOf(context) == ViewSize.phone ? 5 : 3,
                                ),
                                productionYear: value.overview.productionYear?.toString(),
                                runTime: value.overview.runTime,
                                genres: value.overview.genreItems,
                                studios: value.overview.studios,
                                officialRating: value.overview.parentalRating,
                                communityRating: value.overview.communityRating,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.carouselType != HomeCarouselSettings.recommendations)
                Builder(builder: (context) {
                  return FocusProvider(
                    autoFocus: true,
                    child: PosterRow(
                      primaryPosters: true,
                      label: context.localized.nextUp,
                      posters: widget.items,
                      onFocused: (poster) {
                        timer.reset();
                        context.ensureVisible(
                          alignment: 10.0,
                        );
                        selectedItem.value = poster;
                        widget.onSelect(poster);
                      },
                    ),
                  );
                }),
              const SizedBox(height: 16)
            ],
          ),
        ),
      ],
    );
  }
}
