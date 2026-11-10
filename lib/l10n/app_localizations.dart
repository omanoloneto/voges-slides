import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @fileMenu.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileMenu;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @newFile.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newFile;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get saveAs;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get systemLanguage;

  /// No description provided for @saveChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get saveChangesTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @dontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get dontSave;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @openFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Open presentation'**
  String get openFileTitle;

  /// No description provided for @saveFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Save presentation'**
  String get saveFileTitle;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'This file could not be opened.'**
  String get openFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be saved.'**
  String get saveFailed;

  /// No description provided for @unsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'This kind of file can\'t be opened yet. Save it as .pptx in the other program.'**
  String get unsupportedFormat;

  /// No description provided for @openedWithLosses.
  ///
  /// In en, this message translates to:
  /// **'Parts of this presentation that are not supported yet, such as tables, charts, notes or animations, were left out. Saving creates a new file, so the original stays as it is.'**
  String get openedWithLosses;

  /// No description provided for @nothingToPaste.
  ///
  /// In en, this message translates to:
  /// **'Nothing to paste.'**
  String get nothingToPaste;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @fitZoom.
  ///
  /// In en, this message translates to:
  /// **'Fit slide to window'**
  String get fitZoom;

  /// No description provided for @clipboardGroup.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboardGroup;

  /// No description provided for @slidesGroup.
  ///
  /// In en, this message translates to:
  /// **'Slides'**
  String get slidesGroup;

  /// No description provided for @insertGroup.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insertGroup;

  /// No description provided for @fontGroup.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontGroup;

  /// No description provided for @paragraphGroup.
  ///
  /// In en, this message translates to:
  /// **'Paragraph'**
  String get paragraphGroup;

  /// No description provided for @shapeGroup.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get shapeGroup;

  /// No description provided for @slideshowGroup.
  ///
  /// In en, this message translates to:
  /// **'Slideshow'**
  String get slideshowGroup;

  /// No description provided for @newSlide.
  ///
  /// In en, this message translates to:
  /// **'New slide'**
  String get newSlide;

  /// No description provided for @duplicateSlide.
  ///
  /// In en, this message translates to:
  /// **'Duplicate slide'**
  String get duplicateSlide;

  /// No description provided for @deleteSlide.
  ///
  /// In en, this message translates to:
  /// **'Delete slide'**
  String get deleteSlide;

  /// No description provided for @moveSlideUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveSlideUp;

  /// No description provided for @moveSlideDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveSlideDown;

  /// No description provided for @slideBackground.
  ///
  /// In en, this message translates to:
  /// **'Slide background'**
  String get slideBackground;

  /// No description provided for @backgroundAllSlides.
  ///
  /// In en, this message translates to:
  /// **'Apply to all slides'**
  String get backgroundAllSlides;

  /// No description provided for @layoutTitleSlide.
  ///
  /// In en, this message translates to:
  /// **'Title slide'**
  String get layoutTitleSlide;

  /// No description provided for @layoutTitleContent.
  ///
  /// In en, this message translates to:
  /// **'Title and content'**
  String get layoutTitleContent;

  /// No description provided for @layoutTitleOnly.
  ///
  /// In en, this message translates to:
  /// **'Title only'**
  String get layoutTitleOnly;

  /// No description provided for @layoutBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank'**
  String get layoutBlank;

  /// No description provided for @textBox.
  ///
  /// In en, this message translates to:
  /// **'Text box'**
  String get textBox;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @shapes.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get shapes;

  /// No description provided for @insertImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get insertImageTitle;

  /// No description provided for @imageFailed.
  ///
  /// In en, this message translates to:
  /// **'This image could not be opened.'**
  String get imageFailed;

  /// No description provided for @shapeRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get shapeRectangle;

  /// No description provided for @shapeRoundedRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rounded rectangle'**
  String get shapeRoundedRectangle;

  /// No description provided for @shapeEllipse.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get shapeEllipse;

  /// No description provided for @shapeTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get shapeTriangle;

  /// No description provided for @shapeRightTriangle.
  ///
  /// In en, this message translates to:
  /// **'Right triangle'**
  String get shapeRightTriangle;

  /// No description provided for @shapeDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get shapeDiamond;

  /// No description provided for @shapePentagon.
  ///
  /// In en, this message translates to:
  /// **'Pentagon'**
  String get shapePentagon;

  /// No description provided for @shapeHexagon.
  ///
  /// In en, this message translates to:
  /// **'Hexagon'**
  String get shapeHexagon;

  /// No description provided for @shapeStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get shapeStar;

  /// No description provided for @shapeRightArrow.
  ///
  /// In en, this message translates to:
  /// **'Right arrow'**
  String get shapeRightArrow;

  /// No description provided for @shapeLeftArrow.
  ///
  /// In en, this message translates to:
  /// **'Left arrow'**
  String get shapeLeftArrow;

  /// No description provided for @shapeUpArrow.
  ///
  /// In en, this message translates to:
  /// **'Up arrow'**
  String get shapeUpArrow;

  /// No description provided for @shapeDownArrow.
  ///
  /// In en, this message translates to:
  /// **'Down arrow'**
  String get shapeDownArrow;

  /// No description provided for @shapeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get shapeLine;

  /// No description provided for @shapeArrowLine.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get shapeArrowLine;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontFamily;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @growFont.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get growFont;

  /// No description provided for @shrinkFont.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get shrinkFont;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @underline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get underline;

  /// No description provided for @strikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get strikethrough;

  /// No description provided for @textColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get textColor;

  /// No description provided for @alignLeft.
  ///
  /// In en, this message translates to:
  /// **'Align left'**
  String get alignLeft;

  /// No description provided for @alignCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get alignCenter;

  /// No description provided for @alignRight.
  ///
  /// In en, this message translates to:
  /// **'Align right'**
  String get alignRight;

  /// No description provided for @justify.
  ///
  /// In en, this message translates to:
  /// **'Justify'**
  String get justify;

  /// No description provided for @bullets.
  ///
  /// In en, this message translates to:
  /// **'Bullets'**
  String get bullets;

  /// No description provided for @numbering.
  ///
  /// In en, this message translates to:
  /// **'Numbering'**
  String get numbering;

  /// No description provided for @decreaseIndent.
  ///
  /// In en, this message translates to:
  /// **'Decrease indent'**
  String get decreaseIndent;

  /// No description provided for @increaseIndent.
  ///
  /// In en, this message translates to:
  /// **'Increase indent'**
  String get increaseIndent;

  /// No description provided for @textPosition.
  ///
  /// In en, this message translates to:
  /// **'Text position'**
  String get textPosition;

  /// No description provided for @alignTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get alignTop;

  /// No description provided for @alignMiddle.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get alignMiddle;

  /// No description provided for @alignBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get alignBottom;

  /// No description provided for @fillColor.
  ///
  /// In en, this message translates to:
  /// **'Fill color'**
  String get fillColor;

  /// No description provided for @noFill.
  ///
  /// In en, this message translates to:
  /// **'No fill'**
  String get noFill;

  /// No description provided for @outlineColor.
  ///
  /// In en, this message translates to:
  /// **'Outline color'**
  String get outlineColor;

  /// No description provided for @noOutline.
  ///
  /// In en, this message translates to:
  /// **'No outline'**
  String get noOutline;

  /// No description provided for @outlineWidth.
  ///
  /// In en, this message translates to:
  /// **'Outline width'**
  String get outlineWidth;

  /// No description provided for @arrange.
  ///
  /// In en, this message translates to:
  /// **'Arrange'**
  String get arrange;

  /// No description provided for @bringToFront.
  ///
  /// In en, this message translates to:
  /// **'Bring to front'**
  String get bringToFront;

  /// No description provided for @sendToBack.
  ///
  /// In en, this message translates to:
  /// **'Send to back'**
  String get sendToBack;

  /// No description provided for @bringForward.
  ///
  /// In en, this message translates to:
  /// **'Bring forward'**
  String get bringForward;

  /// No description provided for @sendBackward.
  ///
  /// In en, this message translates to:
  /// **'Send backward'**
  String get sendBackward;

  /// No description provided for @unlockBackground.
  ///
  /// In en, this message translates to:
  /// **'Unlock background elements'**
  String get unlockBackground;

  /// No description provided for @slideshowFromStart.
  ///
  /// In en, this message translates to:
  /// **'From beginning'**
  String get slideshowFromStart;

  /// No description provided for @slideshowFromCurrent.
  ///
  /// In en, this message translates to:
  /// **'From current slide'**
  String get slideshowFromCurrent;

  /// No description provided for @slideshowEnd.
  ///
  /// In en, this message translates to:
  /// **'End of slideshow. Click to exit.'**
  String get slideshowEnd;

  /// No description provided for @promptTitle.
  ///
  /// In en, this message translates to:
  /// **'Click to add title'**
  String get promptTitle;

  /// No description provided for @promptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Click to add subtitle'**
  String get promptSubtitle;

  /// No description provided for @promptText.
  ///
  /// In en, this message translates to:
  /// **'Click to add text'**
  String get promptText;

  /// No description provided for @saveChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save the changes to \"{name}\"?'**
  String saveChangesMessage(String name);

  /// No description provided for @slideOf.
  ///
  /// In en, this message translates to:
  /// **'Slide {current} of {total}'**
  String slideOf(int current, int total);

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'{value} pt'**
  String points(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
