part of 'deck_controller.dart';

mixin _Slides on _Deck {
  Slide? _slideClip;

  bool get canDeleteSlide => slides.length > 1;
  bool get canPasteSlide => _slideClip != null;

  void selectSlide(int index) {
    final target = index.clamp(0, slides.length - 1);
    if (target == _slideIndex) return;
    stopEditing();
    _slideIndex = target;
    _selection = const {};
    _coalesceKey = null;
    notifyListeners();
  }

  /// Adds a slide after the current one, with its background and look.
  void addSlide([SlideLayout layout = SlideLayout.titleContent]) {
    stopEditing();
    _record();
    final current = slide;
    _insert(
      Slide(
        id: _newId(),
        background: current.background,
        backgroundImage: current.backgroundImage,
        elements: [
          for (final element in current.elements)
            if (element.locked) _fresh(element),
          ...layoutElements(
            layout,
            _presentation.size,
            _newId,
            look: LayoutLook.of(current),
          ),
        ],
      ),
    );
  }

  void duplicateSlide() {
    stopEditing();
    _record();
    _insert(_copyOf(slide));
  }

  void deleteSlide() {
    if (!canDeleteSlide) return;
    stopEditing();
    _record();
    final index = _slideIndex;
    _setSlides([...slides.take(index), ...slides.skip(index + 1)]);
    _slideIndex = math.min(index, slides.length - 1);
    _selection = const {};
    notifyListeners();
  }

  /// Moves a slide so it ends at index [to].
  void moveSlide(int from, int to) {
    final target = to.clamp(0, slides.length - 1);
    if (from < 0 || from >= slides.length || from == target) return;
    stopEditing();
    _record();
    final moved = [...slides];
    moved.insert(target, moved.removeAt(from));
    _setSlides(moved);
    _slideIndex = target;
    _selection = const {};
    notifyListeners();
  }

  void copySlide() => _slideClip = slide;

  void pasteSlide() {
    final copied = _slideClip;
    if (copied == null) return;
    stopEditing();
    _record();
    _insert(_copyOf(copied));
  }

  void setBackground(int color, {bool allSlides = false}) {
    _record();
    _setSlides([
      for (var index = 0; index < slides.length; index++)
        allSlides || index == _slideIndex
            ? slides[index].copyWith(background: color, backgroundImage: null)
            : slides[index],
    ]);
    notifyListeners();
  }

  Slide _copyOf(Slide source) => source.copyWith(
    id: _newId(),
    elements: [for (final element in source.elements) _fresh(element)],
  );

  void _insert(Slide added) {
    final index = _slideIndex + 1;
    _setSlides([...slides.take(index), added, ...slides.skip(index)]);
    _slideIndex = index;
    _selection = const {};
    notifyListeners();
  }
}
