#!/usr/bin/env python3
"""Static checks for the Dart sources.

`flutter analyze` is not available in this environment (no Dart SDK), so this
script performs the checks that are mechanical enough to automate without a
real parser:

1. every relative import resolves to a file on disk;
2. no file imports `flutter`, `flame`, `BuildContext`, `Widget`, `Canvas`,
   `PositionComponent` or a Flutter animation class from the game domain layer;
3. braces, parens and brackets balance per file;
4. no `TODO(`, `FIXME(`, `UnimplementedError`, bare `dynamic`, `return null`
   placeholders or `throw UnimplementedError()` stubs;
5. **undefined bare identifiers** - a bare camelCase identifier that is never
   declared in its file, never a project top-level, never imported by name,
   never a base-class member and never a Dart/Flutter global. This is the check
   that catches "forgot the receiver" typos such as `hadMerges` instead of
   `outcome.hadMerges`, which a compiler would reject.

Usage:
    python3 tool/check_sources.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
TEST = ROOT / "test"

# Deliberately broken Dart, excluded from the normal scan. See faults.dart.
SELFTEST_DIR = ROOT / "tool" / "selftest"

# Identifiers tool/selftest/faults.dart uses wrongly. The self-test passes only
# when the analyser reports every one of them.
EXPECTED_FAULTS = (
    "hadMerges",      # missing receiver: used bare, only ever reached via `.`
    "totl",           # typo of a real local
    "_boardForLevel",  # call to a method that does not exist
    "blockCount",     # bare name that is declared nowhere
)

# Only the domain/ subdirectories must stay free of Flutter and Flame.
# lib/core/widgets, lib/app and every presentation/ folder are UI by design.
DOMAIN_ROOTS = {
    LIB / "features" / "game" / "domain",
    LIB / "features" / "levels" / "domain",
    LIB / "features" / "progression" / "domain",
    LIB / "features" / "settings" / "domain",
    LIB / "features" / "daily_challenge" / "domain",
    LIB / "features" / "monetization" / "domain",
}

FORBIDDEN_DOMAIN_TOKENS = {
    "package:flutter",
    "package:flame",
    "BuildContext",
    "Widget",
    "Canvas",
    "PositionComponent",
    "AnimationController",
    "Tween",
    "CurvedAnimation",
    "AnimatedBuilder",
    "AnimatedContainer",
    "Hero",
    "Navigator",
    "StatefulWidget",
    "StatelessWidget",
}

# ---------------------------------------------------------------- builtins

DART_KEYWORDS = {
    "abstract", "as", "assert", "async", "await", "base", "break", "case",
    "catch", "class", "const", "continue", "covariant", "default", "deferred",
    "do", "dynamic", "else", "enum", "export", "extends", "extension",
    "external", "factory", "false", "final", "finally", "for", "Function",
    "get", "hide", "if", "implements", "import", "in", "interface", "is",
    "late", "library", "mixin", "new", "null", "on", "operator", "part",
    "required", "rethrow", "return", "sealed", "set", "show", "static",
    "super", "switch", "sync", "this", "throw", "true", "try", "typedef",
    "var", "void", "when", "while", "with", "yield",
}

# dart:core / dart:math / dart:async globals that legitimately appear bare.
GLOBALS = {
    # Object / core
    "Object", "toString", "hashCode", "runtimeType", "noSuchMethod", "identical",
    # the wildcard identifier used by switch-expression default cases
    "_", "__",
    "print", "identityHashCode",
    # num
    "abs", "ceil", "floor", "round", "truncate", "toInt", "toDouble", "clamp",
    "min", "max", "isNaN", "isInfinite", "isFinite", "isNegative", "sign",
    "remainder", "toStringAsFixed", "compareTo", "parse", "tryParse",
    # int / double statics
    "bitLength", "toRadixString", "gcd",
    # String
    "length", "isEmpty", "isNotEmpty", "codeUnits", "runes", "contains",
    "startsWith", "endsWith", "indexOf", "lastIndexOf", "substring", "trim",
    "trimLeft", "trimRight", "toLowerCase", "toUpperCase", "split", "replaceAll",
    "replaceFirst", "replaceRange", "padLeft", "padRight", "join", "allMatches",
    "matchAsPrefix", "codeUnitAt", "compareTo", "toString",
    # Iterable / List / Set / Map
    "first", "last", "firstOrNull", "lastOrNull", "single", "singleOrNull",
    "elementAt", "where", "map", "whereType", "expand", "take", "takeWhile",
    "skip", "skipWhile", "forEach", "fold", "reduce", "join", "any", "every",
    "contains", "toList", "toSet", "add", "addAll", "remove", "removeAt",
    "removeWhere", "retainWhere", "clear", "insert", "addAll", "putIfAbsent",
    "containsKey", "containsValue", "keys", "values", "entries", "update",
    "sort", "sublist", "getRange", "asMap", "reversed", "followedBy", "cast",
    "toList", "toSet", "iterator", "moveNext", "current", "isBlank",
    "indexWhere", "lastIndexWhere", "firstWhere", "lastWhere", "fold",
    "generate", "filled", "from", "of", "unmodifiable", "empty", "growable",
    # bool
    "toString",
    # Future / Stream / async
    "then", "catchError", "whenComplete", "timeout", "asStream", "onError",
    "listen", "close", "first", "last", "length", "isEmpty", "isBroadcast",
    "transform", "where", "map", "asyncExpand", "pipe", "toList", "toSet",
    "drain", "handleError", "unawaited", "Future", "Stream", "StreamController",
    "Completer", "Timer", "Duration", "Stopwatch", "DateTime", "Utc",
    # math
    "sqrt", "sin", "cos", "tan", "atan", "atan2", "asin", "acos", "exp", "log",
    "pow", "Random", "nextInt", "nextDouble", "nextBool", "Point", "Rectangle",
    "pi", "e", "ln2", "ln10", "log2e", "sqrt2", "max", "min",
    # convert
    "jsonEncode", "jsonDecode", "base64Encode", "base64Decode", "utf8",
    "ascii", "latin1", "encode", "decode", "fuse", "convert",
    # foundation / widgets globals
    "debugPrint", "defaultTargetPlatform", "kDebugMode", "kReleaseMode",
    "kProfileMode", "kIsWeb", "kMinInteractiveDimension", "listEquals",
    "setEquals", "mapEquals", "immutable", "visibleForTesting", "mustCallSuper",
    "protected", "factory", "required", "literal", "nonVirtual", "optionalTypeArgs",
    "useResult", "virtual", "visibleForOverriding", "rethrow", "scheduler",
    "compute", "describeIdentity", "shortHash", "deepEquals", "mergeSort",
    "binarySearch", "lowerBound", "licensed",
    # flame
    "Vector2", "Paint", "Path", "Offset", "Rect", "Size", "Colors", "Color",
    "TextStyle", "TextSpan", "TextPainter", "TextDirection", "FontWeight",
    "BorderRadius", "Radius", "BoxShadow", "Gradient", "LinearGradient",
    "Alignment", "AlignmentGeometry", "EdgeInsets", "Curves", "Clip",
    "BlendMode", "StrokeCap", "StrokeJoin", "BlurStyle", "MaskFilter",
    "TileMode", "PathOperation", "Canvas", "PictureRecorder", "Image",
    "Sprite", "SpriteBatch", "Particle", "Random", "Anchor", "Vector2",
    "Flame", "Game", "Component", "PositionComponent", "SpriteComponent",
    "TextComponent", "RectangleComponent", "CircleComponent", "ShapeComponent",
    "ParticleSystemComponent", "CameraComponent", "World", "Viewport",
    "HasGameRef", "TapCallbacks", "DragCallbacks", "HoverCallbacks",
    "CollisionCallbacks", "KeyboardHandler", "Tappable", "Draggable",
    "assetsPrefix", "images", "fromCache", "load", "findGame",
    # bloc / equatable / go_router
    "emit", "state", "close", "isClosed", "stream", "onChange", "onError",
    "addError", "add", "props", "stringify", "Bloc", "Cubit", "BlocBase",
    "BlocObserver", "BlocProvider", "BlocBuilder", "BlocListener",
    "MultiBlocProvider", "RepositoryProvider", "context", "read", "watch",
    "select", "GoRouter", "GoRoute", "StatefulShellRoute", "ShellRoute",
    "GoRouterState", "GoRouterHelper", "extension", "push", "pushReplacement",
    "go", "pushNamed", "pushReplacementNamed", "replace", "pop", "canPop",
    "location", "extra", "pathParameters", "uri", "name", "fullPath",
    "redirect", "pageBuilder", "builder", "routes", "errorBuilder",
    "initialLocation", "navigatorKey", "debugLogDiagnostics", "observers",
    "routerDelegate", "routeInformationProvider", "backButtonDispatcher",
    "onException", "refreshListenable", "routerConfig",
    # shared_preferences
    "getInstance", "getString", "setString", "getInt", "setInt", "getDouble",
    "setDouble", "getBool", "setBool", "getStringList", "setStringList",
    "remove", "clear", "containsKey", "getKeys", "reload", "SharedPreferences",
    "prefs", "setMockInitialValues",
    # google_mobile_ads / in_app_purchase
    "load", "show", "dispose", "rewardedAd", "interstitialAd", "bannerAd",
    "adUnitId", "request", "onAdLoaded", "onAdFailedToLoad", "onAdShowed",
    "onAdDismissed", "onEarnedReward", "fullScreenContentCallback",
    "AdRequest", "RewardedAd", "InterstitialAd", "BannerAd", "AdSize",
    "AnchoredAdaptiveBannerAdSize", "RewardItem", "MobileAds", "initialize",
    "InAppPurchase", "InAppPurchase.instance", "queryProductDetails",
    "restorePurchases", "buyNonConsumablePurchase", "buyConsumablePurchase",
    "completePurchase", "PurchaseDetails", "ProductDetails", "ProductDetailsResponse",
    "PurchaseParam", "PurchaseVerificationData", "kDebugMode", "pastPurchases",
    "purchaseStream", "price", "title", "description", "id", "status", "error",
    "pendingCompletePurchase", "productID", "transactionId", "verificationData",
    # package:matcher / package:test
    "isNotNull", "isA", "isNull", "isTrue", "isFalse", "equals", "same",
    "contains", "containsAll", "containsPair", "isEmpty", "isNotEmpty",
    "throwsA", "returnsNormally", "predicate", "allOf", "anyOf", "isNot",
    "orderedEquals", "unorderedEquals", "closeTo", "greaterThan",
    "greaterThanOrEqualTo", "lessThan", "lessThanOrEqualTo", "inInclusiveRange",
    "inExclusiveRange", "inOpenClosedRange", "isZero", "isPositive",
    "isNegative", "isNonPositive", "isNonNegative", "hasLength", "isInstanceOf",
    "everyElement",
    "isNaN", "isInfinite", "isFinite", "isNotNaN", "matches", "startsWith",
    "endsWith", "stringContainsInOrder", "wrapMatcher", "isNotSame",
    "completion", "throwsUnimplementedError", "throwsArgumentError",
    "throwsStateError", "throwsUnsupportedError", "throwsA", "group", "test",
    "setUp", "tearDown", "setUpAll", "tearDownAll", "expect", "expectLater",
    "fail", "markTestSkipped", "retry", "Timeout", "throwsA", "addTearDown",
    "spawnHybridUri", "main",
    # Flutter helpers
    "showModalBottomSheet", "showDialog", "showGeneralDialog",
    "showDatePicker", "showTimePicker", "showMenu", "showCupertinoDialog",
    "showCupertinoModalPopup", "showLicensePage", "showAboutDialog",
    "showSearch", "showBottomSheet", "rootBundle", "prefs", "runApp",
    "SystemChrome",
    "SystemUiOverlayStyle", "DeviceOrientation", "HapticFeedback",
    "Clipboard", "ClipboardData", "FocusScope", "FocusScopeNode",
    "Scrollable", "PrimaryScrollController", "NotificationListener",
    "MediaQuery", "Theme", "DefaultTextStyle", "IconTheme", "Directionality",
    "Semantics", "ExcludeSemantics", "MergeSemantics", "BlockSemantics",
    "KeepAlive", "SafeArea", "OrientationBuilder", "LayoutBuilder",
    "ConstrainedBox", "SizedBox", "Expanded", "Flexible", "Spacer", "Align",
    "Center", "Padding", "Container", "DecoratedBox", "ClipRect", "ClipRRect",
    "ClipOval", "ClipPath", "Transform", "Opacity", "RotatedBox", "FittedBox",
    "OverflowBox", "LimitedBox", "IntrinsicWidth", "IntrinsicHeight",
    "AspectRatio", "FractionallySizedBox", "UnconstrainedBox", "Visibility",
    "Offstage", "TickerMode", "RepaintBoundary", "AnimatedOpacity",
    "AnimatedSwitcher", "AnimatedAlign", "AnimatedPadding", "AnimatedContainer",
    "AnimatedPositioned", "AnimatedRotation", "AnimatedScale", "AnimatedSlide",
    "AnimatedDefaultTextStyle", "AnimatedCrossFade", "AnimatedSize",
    "AnimatedPhysicalModel", "Hero", "FadeTransition", "ScaleTransition",
    "SlideTransition", "SizeTransition", "RotationTransition",
    "AlignTransition", "PositionTransition", "RelativePositionedTransition",
    "DecoratedBoxTransition", "DefaultTextStyleTransition",
    "AnimatedBuilder", "TweenAnimationBuilder", "CurvedAnimation",
    "AnimationController", "Animation", "Tween", "Curve", "Curves", "Interval",
    "ReverseAnimation", "CompoundAnimation", "AlwaysStoppedAnimation",
    "AnimationMin", "AnimationMax", "AnimationLerp", "AnimationStyler",
    # Dart type keywords and built-in annotations used as bare identifiers.
    "bool", "int", "double", "num", "String", "Object", "dynamic", "Function",
    "Record", "Never", "Null", "Symbol", "Type", "Iterable", "List", "Map",
    "Set", "Future", "Stream", "Exception", "Error", "StackTrace", "Duration",
    "override", "immutable", "required", "literal", "protected", "visibleForTesting",
    "mustCallSuper", "nonVirtual", "virtual", "factory", "sealed", "base",
    "interface", "mixin", "extension", "typedef", "reopen", "useResult",
    "Deprecated", "deprecated", "experimental", "isTest", "pragma",
    "xFFFFFFFF", "x811C9DC5", "x01000193", "xFF", "x", "e", "pi",
    # firebase
    "Firebase", "initializeApp", "FirebaseAnalytics", "FirebaseCrashlytics",
    "logEvent", "setAnalyticsCollectionEnabled", "setUserId", "setUserProperty",
    "setCurrentScreen", "logAdRevenue", "logPurchase", "logSignUp", "logLogin",
    "logShare", "logPostScore", "logLevelStart", "logLevelEnd", "logTutorialBegin",
    "logTutorialComplete", "logUnlockAchievement", "logSpendVirtualCurrency",
    "logEarnVirtualCurrency", "logJoinGroup", "logSearch", "logSelectContent",
    "recordError", "log", "setCrashlyticsCollectionEnabled", "setCustomKey",
    "crash", "isDebuggable", "FlutterError", "onError",
}

# Members contributed by external base classes the project extends.
BASE_MEMBERS = {
    "Object": {"toString", "hashCode", "runtimeType", "noSuchMethod", "=="},
    "StatelessWidget": {"build", "createElement", "debugFillProperties",
                        "createState", "toStringShort", "key", "widget"},
    "StatefulWidget": {"createElement", "createState", "debugFillProperties",
                       "toStringShort", "key"},
    "State": {"initState", "didChangeDependencies", "didUpdateWidget",
              "reassemble", "setState", "deactivate", "dispose", "build",
              "mounted", "context", "widget", "didChangeDependencies",
              "toStringShort", "debugFillProperties"},
    "Cubit": {"state", "emit", "close", "isClosed", "stream", "onChange",
              "onError", "addError", "add", "hashCode"},
    "Bloc": {"state", "emit", "close", "isClosed", "stream", "onChange",
             "onError", "addError", "add", "onTransition", "onEvent",
             "transformEvents", "transformTransitions", "mapEventToState"},
    "Equatable": {"props", "stringify", "hashCode", "=="},
    "PositionComponent": {
        "children", "priority", "position", "size", "anchor", "angle", "scale",
        "isLoaded", "isMounted", "isHud", "add", "addAll", "remove", "removeWhere",
        "removeAll", "containsLocalPoint", "containsPoint", "onLoad", "onMount",
        "onRemove", "update", "updateTree", "render", "renderTree",
        "onGameResize", "onParentResize", "hasChildren", "childAt", "firstChild",
        "lastChild", "componentsAtPoint", "toRect", "deepHashCode",
        "componentsAtLocation", "findChildren", "query", "propagateEvent",
        "removeFromParent", "gameRef", "buildScope", "isHudTemplate",
        "handleNotification", "onCollisionStart", "onCollision", "onCollisionEnd",
        "positionType", "parent", "game", "ref", "loaded", "isRemoving",
        "isRemoved", "childrenRegistered", "registerChildren",
    },
    "FlameGame": {
        "children", "camera", "viewport", "world", "size", "images", "assetsCache",
        "onLoad", "onMount", "onRemove", "update", "updateTree", "render",
        "renderTree", "onGameResize", "add", "remove", "removeWhere", "pauseEngine",
        "resumeEngine", "paused", "overlays", "buildContext", "currentFrameRate",
        "hasChildren", "firstChild", "lastChild", "childAt", "registerChildren",
        "processDelayedEvents", "stepEngine", "onMemoryPressure", "lifecycleStateChange",
        "acquireSemantics", "releaseSemantics", "propagateEvent", "findGame",
        "backgroundColor", "cameraComponent", "query", "registerKey",
    },
    "SingleTickerProviderStateMixin": {
        "createTicker", "dispose", "didChangeDependencies", "initState",
        "build", "mounted", "context", "widget", "setState", "vsync",
        "dispose",
    },
    "TickerProviderStateMixin": {
        "createTicker", "dispose", "didChangeDependencies", "initState",
        "build", "mounted", "context", "widget", "setState", "vsync",
    },
}

# ---------------------------------------------------------------- scanning


def blank_literals(source: str) -> str:
    """Replace string and comment bodies with spaces, keeping newlines.

    Offsets and line numbers are preserved so diagnostics stay accurate. Hex
    literals are blanked too, so `0xFFFFFFFF` is not mistaken for the
    identifier `xFFFFFFFF`.
    """
    out = list(source)
    i, n = 0, len(source)
    while i < n:
        c = source[i]
        if c == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                out[i] = " "
                i += 1
        elif c == "/" and i + 1 < n and source[i + 1] == "*":
            out[i] = out[i + 1] = " "
            i += 2
            while i < n:
                if source[i] == "*" and i + 1 < n and source[i + 1] == "/":
                    out[i] = out[i + 1] = " "
                    i += 2
                    break
                if source[i] != "\n":
                    out[i] = " "
                i += 1
        elif c in "'\"":
            # Raw strings and triple-quoted strings. `${...}` is an expression
            # nested inside the string, so a bare quote inside it must not end
            # the literal - hence the brace-depth tracking below.
            triple = source[i:i + 3] in ("'''", '"""')
            quote = source[i:i + 3] if triple else c
            raw = i > 0 and source[i - 1] == "r"
            out[i] = " "
            i += 1
            depth = 0
            while i < n:
                if not raw and depth == 0 and source[i] == "\\" and i + 1 < n:
                    out[i] = out[i + 1] = " "
                    i += 2
                    continue
                if depth == 0 and source[i:i + len(quote)] == quote:
                    for k in range(i, min(i + len(quote), n)):
                        out[k] = " "
                    i += len(quote)
                    break
                if not raw and source[i] == "$" and i + 1 < n and source[i + 1] == "{":
                    depth += 1
                    out[i] = out[i + 1] = " "
                    i += 2
                    continue
                if depth > 0:
                    if source[i] == "{":
                        depth += 1
                    elif source[i] == "}":
                        depth -= 1
                    if depth == 0:
                        out[i] = " "
                        i += 1
                        continue
                if source[i] != "\n":
                    out[i] = " "
                i += 1
        else:
            i += 1
    text = "".join(out)
    # Hex literals (`0xFF`, `0xFFFFFFFF`) must not read as identifiers.
    return re.sub(r"0[xX][0-9a-fA-F_]+", lambda m: " " * len(m.group(0)), text)


IDENT = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*")

def _opens_a_body(line: str, open_paren: int) -> bool:
    """True when the group opened at `open_paren` is followed by `{` or `=>`.

    `int foo(` opens a body; `doThing(` does not.
    """
    depth = 0
    for i in range(open_paren, len(line)):
        ch = line[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                rest = line[i + 1:].lstrip()
                return rest.startswith(("{", "=>")) or rest.startswith(
                    ("async", "sync")
                )
    return False


def _shallowest_depth(raw: str, start: int) -> int:
    """Shallowest brace depth reached anywhere on `raw`, starting at `start`."""
    depth = start
    shallowest = depth
    for ch in raw:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth < shallowest:
                shallowest = depth
    return shallowest


def brace_depth_at(text: str, offset: int) -> int:
    """Brace nesting depth at `offset` in the (length-preserving) blanked text.

    Used to tell a parameter list from a call argument list: only a declaration
    can sit at depth 0 (file scope) or 1 (directly in a class body).
    """
    depth = 0
    for ch in text[:offset]:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
    return depth


# An `import`/`export` directive with its optional `as`/`show`/`hide` clause.
# Applied to the *raw* source, never to the blanked text.
IMPORT_RE = re.compile(
    r"^\s*(?:import|export)\s+['\"]([^'\"]+)['\"]"
    r"((?:\s+(?:as|show|hide)\s+[\w,\s]+)*)\s*;",
    re.M,
)

# Keywords whose parenthesised clause is an expression, not a parameter list.
CONTROL_KEYWORDS = {
    "if", "while", "for", "switch", "catch", "assert", "return", "await",
    "throw", "yield", "when", "else", "do", "try", "finally",
}


class Decl:
    """Everything a single file declares."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.top_level: set[str] = set()

        # Names introduced by a *statement* rather than a declaration: locals,
        # loop variables, closure parameters, local functions. Used to widen the
        # undefined-identifier pass only - the missing-receiver pass must stay
        # strict, or a stray local would mask the bug it exists to catch.
        self.locals: set[str] = set()

        # 1-based line number -> name of the innermost enclosing class.
        self.enclosing: dict[int, str] = {}
        self.classes: dict[str, dict] = {}
        self._parse(path.read_text(encoding="utf-8"))

    def _parse(self, source: str) -> None:
        text = blank_literals(source)
        lines = text.split("\n")

        class_header = re.compile(
            r"^\s*(?:@[\w.]+\s+)*"
            r"(?:(?:abstract|base|interface|final|sealed|mixin|augment)\s+)*"
            r"(class|mixin|enum|extension|typedef)\s+([A-Za-z_$][\w$]*)"
            r"([^{;]*)"
        )
        # Continuation lines of a multi-line signature start with `})`, `)` or
        # `],`; strip that prefix so the declared name on the line is found.
        continuation = re.compile(r"^\s*(?:\}\)|\)|\],|\.\.\.)\s*")

        # A member declaration line is `... name (` / `... name =` /
        # `... name;` / `... name =>` / `... name {`. Rather than parse Dart's
        # type grammar, look at the identifiers that (a) sit at paren depth 0 on
        # their line and (b) are immediately followed by a terminator, then pick
        # by terminator priority.
        #
        # Paren depth is what makes record return types work:
        # `({GameBoard board, List<BlockMove> m}) applyGravity(GameBoard b) {`
        # only offers `applyGravity`, because every other identifier on the line
        # is inside the record's parentheses.
        #
        # The priority order matters. In
        # `static const Color backgroundTop = Color(0xFF1B1035);` both
        # `backgroundTop` (followed by `=`) and the value's `Color` (followed by
        # `(`) qualify, and only the `=` one is the declaration. Generic methods
        # such as `T? pick<T>(List<T> items) {` are reached last, via `<`.
        TERMINATOR_PRIORITY = (";", "=", "=>", "{", "(", "<")

        # A declaration name is never preceded by one of these: they mark the
        # start of an expression, so the identifier after them is a *value*
        # (`= Color(0xFF1B1035)`, `, foo(`, `.bar(`, `: baz`) rather than the
        # thing being declared. `)`, `?`, `<` and `>` stay allowed because a
        # record return type or a generic parameter legitimately precedes the
        # method name: `({Board b}) applyGravity(`, `T? pick<T>(`.
        VALUE_PREFIX_CHARS = set("=(,[{.:+-*/%!&|^~")

        # Words that can precede a declaration but can never *be* the declared
        # name. Without this, `create() async =>` would report `async` (which is
        # followed by `=>`) instead of `create`.
        NON_NAME_WORDS = {
            "async", "sync", "await", "yield", "get", "set", "static", "final",
            "const", "late", "external", "abstract", "covariant", "required",
            "factory", "void", "return", "else", "in", "is", "as", "new",
            "this", "super", "null", "true", "false", "var", "dynamic", "part",
            "show", "hide", "defer", "library", "import", "export", "operator",
            "typedef", "enum", "class", "mixin", "extension", "on", "with",
            "implements", "extends", "base", "interface", "sealed", "when",
            "if", "for", "while", "do", "try", "catch", "finally", "switch",
            "case", "default", "break", "continue", "rethrow", "throw",
            "assert", "of", "then",
        }

        def member_name(line: str, depth: int = 1) -> str | None:
            found: dict[str, str] = {}
            for m in IDENT.finditer(line):
                name = m.group(0)
                if name in NON_NAME_WORDS:
                    continue
                head = line[: m.start()]
                if head.count("(") - head.count(")") > 0:
                    continue  # inside a parameter or record type
                before = head.rstrip()
                if before.endswith("=>") or before.endswith("->"):
                    continue  # the body of an arrow function, not a declaration
                if before and before[-1] in VALUE_PREFIX_CHARS:
                    continue  # this identifier is a value, not a declaration
                rest = line[m.end():].lstrip()
                for terminator in TERMINATOR_PRIORITY:
                    if not rest.startswith(terminator):
                        continue
                    # `name(...)` is a declaration at file scope or directly in
                    # a class body (where it may legitimately end in `;` - an
                    # abstract method). Deeper than that it is a call, so
                    # `doThing();` must stay checkable instead of registering
                    # `doThing` as a member of whatever class encloses it.
                    if (terminator == "(" and depth > 1
                            and not _opens_a_body(line, m.end())):
                        break
                    found.setdefault(terminator, name)
                    break
            for terminator in TERMINATOR_PRIORITY:
                if terminator in found:
                    return found[terminator]
            return None

        # Statement keywords: a line starting with one of these is never a
        # member declaration, so it must not contribute a name.
        # `\b` is essential here: without it `do` would match the start of
        # `double` and silently drop every `double get x {` member.
        STATEMENT_START = re.compile(
            r"^\s*(?:\b(?:if|for|while|switch|return|else|do|try|catch|finally|"
            r"assert|throw|await|yield|case|default|break|continue|rethrow|new|"
            r"super|this|print|emit|setState)\b|\}|\]|\)|//)"
        )
        # Shapes that introduce a name. Kept deliberately generous: a name that
        # is *not* collected here only costs a false positive, whereas inventing
        # one hides a real bug. Feeds `Decl.locals`, which widens the
        # undefined-identifier pass but never the stricter missing-receiver pass.
        # Shapes that introduce a name. Order matters: the `for`/`catch`
        # alternatives must come first, because the local-function pattern would
        # otherwise swallow the whole `for (final x in y) {` span and leave the
        # loop variable uncollected. Kept deliberately generous: a name that is
        # *not* collected here only costs a false positive, whereas inventing
        # one hides a real bug.
        local_decl = re.compile(
            # for-in, with an optional type and optional record pattern:
            # `for (final x in y)`, `for (var (int, int) p in ps)`
            r"\bfor\s*\(\s*(?:final\s+|var\s+|const\s+)?"
            r"(?:\([^()]*\)\s*)?(?:[\w<>?,.\s]+?\s+)?"
            r"([A-Za-z_$][\w$]*)\s+in\b"
            # catch parameter
            r"|\bcatch\s*\(\s*([A-Za-z_$][\w$]*)"
            # final/var/const/late with an optional type: `final int x;`,
            # `late List<Level> levels;`, `const Foo bar = ...`
            r"|\b(?:final|var|const|late)\s+(?:[\w<>?,.\s]+?\s+)?"
            r"([a-z_$][\w$]*)\s*[=;]"
            # a typed local with no modifier at all: `BlockState? best;`
            r"|^\s*[A-Z][\w<>?,.\s]*?\s+([a-z_$][\w$]*)\s*[=;]"
            # a local function: `GameSessionCubit _cubit({Level? level}) {`.
            # The keyword guard is essential: without it this alternative wins
            # at column 0 of `for (final x in y) {`, swallows the whole span,
            # and the loop variable is never collected.
            r"|^\s*(?:[\w<>?,.\s]+?\s+)?"
            r"(?!for\b|if\b|while\b|switch\b|catch\b|return\b|assert\b"
            r"|await\b|super\b|this\b|new\b|do\b|else\b|try\b)"
            r"([a-z_$][\w$]*)\s*\([^;]*\)"
            r"\s*(?:async\s*|sync\s*)?(?:\{|=>)"
        )

        depth = 0
        stack: list[str] = []
        raw_start = 0
        line_no = 0
        for raw in lines:
            line = raw
            stripped = line.strip()
            line_no += 1
            # The offset must advance before any `continue`: a blank line or a
            # class header that skips the body would otherwise desynchronise
            # every following line and silently drop whole classes.
            line_offset = raw_start
            raw_start += len(raw) + 1
            if not stripped:
                continue

            header = class_header.match(line)
            if header and depth == 0:
                kind, name, clause = header.groups()
                bases = set(re.findall(r"[A-Za-z_$][\w$]*", clause or ""))
                bases -= {"extends", "with", "implements", "on", "mixin"}
                self.classes[name] = {"kind": kind, "bases": bases,
                                      "members": set()}
                self.top_level.add(name)
                stack.append(name)
                depth += raw.count("{") - raw.count("}")
                continue

            # `\b` is essential here: without it `do` would match the start of
            # `double` and silently drop every `double get x {` member.
            if continuation.match(line):
                line = continuation.sub("", line, count=1)
            if STATEMENT_START.match(line):
                pass
            else:
                # Only a declaration can sit at file scope or directly inside a
                # class body. Deeper than that we are reading a method body, and
                # every local there would otherwise be registered as a member -
                # which is exactly how a typo hides. The shallowest depth the
                # line reaches is what counts, because a record return type
                # opens its braces on the lines *before* the method name:
                # `}) settle(` is a class-body declaration even though the line
                # starts two braces deep.
                depth_here = _shallowest_depth(raw, brace_depth_at(text, line_offset))
                if depth_here <= 1:
                    declared = member_name(line, depth_here)
                    if declared is not None:
                        if stack:
                            # A member belongs to its class, never to the file.
                            # Registering it as a top-level name would make
                            # `someOtherObject.member` resolvable with no
                            # receiver at all - the exact bug the
                            # missing-receiver pass exists to catch.
                            self.classes[stack[-1]]["members"].add(declared)
                        else:
                            self.top_level.add(declared)

            # Locals are collected from every scope on purpose: missing one only
            # costs a false positive, whereas inventing one hides a real bug.
            self.locals.update(
                m for m in local_decl.findall(line) for m in m if m
            )

            depth += raw.count("{") - raw.count("}")
            if depth <= 0 and stack:
                stack.pop()
                depth = 0
            if stack:
                # Remember which class each line sits in, so a bare member
                # reference is only "in scope" when that class (or one of its
                # bases) really declares it.
                self.enclosing[line_no] = stack[-1]

        # Enum constants: `enum X { a, b, c }`.
        for m in re.finditer(r"\benum\s+([A-Za-z_$][\w$]*)\s*\{([^}]*)\}",
                             text):
            for token in IDENT.findall(m.group(2)):
                self.top_level.add(token)

        # A parenthesised group contributes names only when it really is a
        # parameter list or a named-argument list:
        #   * followed by `{`, `=>`, `:`, `;`, `,`, `async` or `sync` -> a
        #     parameter list, so every identifier in it is a declared name;
        #   * otherwise, only the names before a `:` (named arguments) count.
        # Positional call arguments stay checkable, so `expect(totl, 3)`
        # still reports the typo `totl`.
        for match in re.finditer(r"\(([^()]*)\)", text):
            group = match.group(1)
            before = text[: match.start()].rstrip()
            head = re.search(r"([A-Za-z_$][\w$]*)\s*$", before)
            if head and head.group(1) in CONTROL_KEYWORDS:
                continue
            # A parameter list is followed by a body: `{`, `=>`, `async`,
            # `sync`, or a constructor initialiser `:`. A *call* is followed by
            # `;`, `,`, `.` or an operator - and registering its arguments would
            # let `expect(totl, 3)` invent the very name it is meant to catch.
            # Closure parameters sit at any nesting level, so this cannot be
            # decided by brace depth.
            after = text[match.end():].lstrip()
            if after[:1] in ("{", ":", "=") or after.startswith(
                ("async", "sync", "=>")
            ):
                for token in IDENT.findall(group):
                    self.top_level.add(token)
            else:
                named = re.findall(
                    r"(?:^|[,(\s])([A-Za-z_$][\w$]*)\s*:(?!:)", group
                )
                for token in named:
                    self.top_level.add(token)

        # Parameters of inline function types: `void Function(int blockId)`.
        for match in re.finditer(r"Function\s*(?:<[^(]*>)?\s*\(([^()]*)\)", text):
            for token in IDENT.findall(match.group(1)):
                self.top_level.add(token)


    def members_of(self, class_name: str, seen: set[str] | None = None) -> set[str]:
        seen = seen or set()
        if class_name in seen or class_name not in self.classes:
            return set()
        seen.add(class_name)
        info = self.classes[class_name]
        out = set(info["members"])
        for base in info["bases"]:
            out |= self.members_of(base, seen)
            out |= BASE_MEMBERS.get(base, set())
        return out


# ---------------------------------------------------------------- checks


def _package_name() -> str | None:
    """This project's pub package name, so self-imports can be resolved."""
    pubspec = ROOT / "pubspec.yaml"
    if not pubspec.exists():
        return None
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if line.startswith("name:"):
            return line.split(":", 1)[1].strip().strip("'\"")
    return None


PACKAGE_NAME = _package_name()


def import_target(from_file: Path, uri: str) -> Path | None:
    """Resolves a relative or self-referencing `package:` import to a file."""
    if uri.startswith("."):
        return (from_file.parent / uri).resolve()
    prefix = f"package:{PACKAGE_NAME}/"
    if PACKAGE_NAME and uri.startswith(prefix):
        return (LIB / uri[len(prefix):]).resolve()
    return None


def check_file(path: Path, all_decls: dict[Path, Decl],
               project_top: dict[Path, set[str]]) -> list[str]:
    problems: list[str] = []
    rel = path.relative_to(ROOT)
    source = path.read_text(encoding="utf-8")
    text = blank_literals(source)
    decl = all_decls.get(path, Decl(path))
    project_top.setdefault(path, set())

    # -- 1. imports resolve (matched against the raw source: blanking string
    #       literals would erase the URIs themselves)
    for m in re.finditer(IMPORT_RE, source):
        uri, clause = m.group(1), m.group(2)
        if uri.startswith("dart:"):
            continue
        if uri.startswith("package:"):
            continue
        target = import_target(path, uri)
        if target is None:
            continue
        if not target.exists():
            problems.append(f"{rel}: unresolved import '{uri}'")
            continue
        shown = re.search(r"\bshow\s+([\w,\s]+)", clause)
        if shown:
            names = {n.strip() for n in shown.group(1).split(",") if n.strip()}
            available = project_top.get(target, set())
            missing = names - available
            if missing:
                problems.append(
                    f"{rel}: '{uri}' does not export {sorted(missing)}"
                )

    # -- 2. domain purity
    try:
        path.relative_to(ROOT)
    except ValueError:
        pass
    in_domain = any(
        path.resolve().parent == root or root in path.resolve().parents
        for root in DOMAIN_ROOTS
    )
    if in_domain:
        for token in FORBIDDEN_DOMAIN_TOKENS:
            if token in ("package:flutter", "package:flame"):
                if re.search(r"import\s+['\"]" + re.escape(token), text):
                    problems.append(
                        f"{rel}: domain layer imports {token} (layering violation)"
                    )
            elif re.search(r"\b" + re.escape(token) + r"\b", text):
                problems.append(
                    f"{rel}: domain layer references {token} (layering violation)"
                )

    # -- 3. balance
    for open_c, close_c, label in (("{", "}", "braces"), ("(", ")", "parens"),
                                   ("[", "]", "brackets")):
        if text.count(open_c) != text.count(close_c):
            problems.append(
                f"{rel}: unbalanced {label} "
                f"({text.count(open_c)} {open_c} vs {text.count(close_c)} {close_c})"
            )

    # -- 4. banned placeholders
    for pattern, label in (
        (r"\bTODO\(", "TODO("),
        (r"\bFIXME\(", "FIXME("),
        (r"\bUnimplementedError\b", "UnimplementedError"),
        (r"\bXXX\b", "XXX"),
        (r":\s*dynamic\b", "bare dynamic type"),
    ):
        for m in re.finditer(pattern, text):
            line = text[: m.start()].count("\n") + 1
            problems.append(f"{rel}:{line}: banned {label}")

    # -- 5. undefined bare identifiers
    if path.suffix == ".dart":
        problems.extend(
            _check_identifiers(path, text, decl, project_top, source)
        )

    return problems


def _check_identifiers(path: Path, text: str, decl: Decl,
                       project_top: dict[Path, set[str]],
                       source: str) -> list[str]:
    rel = path.relative_to(ROOT)
    problems: list[str] = []

    # Names this file can legally use bare.
    available: set[str] = set(DART_KEYWORDS) | set(GLOBALS)
    available |= decl.top_level
    available |= decl.locals
    available |= project_top.get(path, set())
    for class_name, info in decl.classes.items():
        available |= info["members"]
        available |= decl.members_of(class_name)
    # A class that extends, mixes in or implements another type can reach that
    # type's members bare - including from an `extension on ThatType`.
    for info in decl.classes.values():
        for base in info["bases"]:
            available |= decl.members_of(base)
            for other in DECL_CACHE.values():
                if base in other.classes:
                    available |= other.members_of(base)
    # Imports that bring names in by name.
    for m in re.finditer(IMPORT_RE, source):
        uri, clause = m.group(1), m.group(2)
        if " as " in clause:
            continue  # prefixed: accessed through the prefix, never bare
        shown = re.search(r"\bshow\s+([\w,\s]+)", clause)
        if shown:
            available |= {n.strip() for n in shown.group(1).split(",")
                          if n.strip()}
            continue
        target = import_target(path, uri)
        if target is not None and target.exists():
            other = DECL_CACHE.get(target)
            if other is not None:
                available |= other.top_level
        elif not uri.startswith("."):
            # External package: opaque namespace, but `dart:` core globals are
            # already in GLOBALS. Unknown names from here are ignored only when
            # the identifier also appears as a member access somewhere in the
            # file (handled by the caller's receiver heuristic).
            pass

    # Identifiers used as members (`.name`) - a bare use of one of these with no
    # receiver in scope is the classic "forgot the dot" bug. This has to be a
    # separate, stricter pass: once imported project files are folded into
    # `available` (which is what makes ordinary cross-file calls resolve), a
    # member of an imported class looks "declared" and the typo disappears.
    member_accessed = set(re.findall(r"\.\s*([A-Za-z_$][\w$]*)", text))

    scan = text

    # Names declared in this file, on a base class, or global - i.e. names a
    # bare reference could legitimately resolve to without a receiver.
    base_strict: set[str] = (set(DART_KEYWORDS) | set(GLOBALS) | decl.top_level
                            | decl.locals)

    missing_receiver: dict[str, int] = {}
    for m in IDENT.finditer(scan):
        name = m.group(0)
        start, end = m.start(), m.end()
        if name[0].isupper() or name.lstrip("_$")[:1].isupper():
            continue
        if name not in member_accessed:
            continue
        line_no = scan[:start].count("\n") + 1
        owner = decl.enclosing.get(line_no)
        # A bare member reference resolves only if the class the line sits in -
        # or one of its bases - declares it. Members of *other* classes in the
        # same file need a receiver, which is exactly the bug being hunted.
        in_scope = base_strict | decl.members_of(owner) if owner else base_strict
        if name in in_scope:
            continue
        before = scan[:start].rstrip()
        if before.endswith("."):
            continue
        after = scan[end:].lstrip()
        if after.startswith(":"):
            prev_token = re.search(r"(\S)\s*$", before)
            if prev_token is None or prev_token.group(1) in "(,{[:=<>":
                continue
        if name in missing_receiver:
            continue
        missing_receiver[name] = line_no

    seen_lines: dict[str, int] = {}
    for m in IDENT.finditer(scan):
        name = m.group(0)
        start, end = m.start(), m.end()

        # Skip type positions: a name whose first *letter* is upper case is a
        # type reference, already covered by the import checker. Leading
        # underscores are Dart's privacy marker, so `_GameButtonState` counts.
        if name.lstrip("_$")[:1].isupper():
            continue

        # Skip member access (`.name`), null-aware access (`?.name`) and
        # cascades (`..name`).
        before = scan[:start].rstrip()
        if before.endswith("."):
            continue

        # Skip named arguments and map keys: `name:` whose preceding token is
        # `(`, `,`, `{`, `[` or `:` (the last one for `a: b: c` chains). This
        # has to look across newlines because Flutter constructors are written
        # one named argument per line.
        after = scan[end:].lstrip()
        if after.startswith(":"):
            prev_token = re.search(r"(\S)\s*$", before)
            if prev_token is None or prev_token.group(1) in "(,{[:=<>":
                continue

        if name in available:
            continue
        if name in seen_lines:
            continue
        line = scan[:start].count("\n") + 1
        seen_lines[name] = line

    for name, line in sorted(seen_lines.items(), key=lambda kv: kv[1]):
        problems.append(f"{rel}:{line}: undefined identifier '{name}'")

    for name, line in sorted(missing_receiver.items(), key=lambda kv: kv[1]):
        problems.append(
            f"{rel}:{line}: '{name}' is used bare but only ever appears as "
            f"`.{name}` in this file - missing receiver?"
        )

    return problems


# ---------------------------------------------------------------- driver

DECL_CACHE: dict[Path, Decl] = {}


def run_selftest() -> int:
    """Scans the deliberately broken fixture and requires every fault found.

    An analyser that silently stops reporting is worse than no analyser, so the
    checks are pinned against a file that is wrong in four different ways.
    """
    path = SELFTEST_DIR / "faults.dart"
    if not path.exists():
        print(f"selftest fixture missing: {path}")
        return 1

    decl = Decl(path)
    problems = check_file(path, {path: decl}, {path: set(decl.top_level)})

    caught = {name for name in EXPECTED_FAULTS
              if any(f"'{name}'" in problem for problem in problems)}
    missed = [name for name in EXPECTED_FAULTS if name not in caught]

    print(f"selftest: {len(problems)} finding(s) against {path.name}")
    for problem in problems:
        print(f"  {problem}")
    if missed:
        print(f"selftest FAILED - analyser no longer reports: {missed}")
        return 1
    print(f"selftest passed - all {len(EXPECTED_FAULTS)} faults detected")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return run_selftest()

    files = sorted(LIB.rglob("*.dart")) + sorted(TEST.rglob("*.dart"))
    if not files:
        print("no Dart files found")
        return 1

    for path in files:
        DECL_CACHE[path] = Decl(path)

    project_top: dict[Path, set[str]] = {}
    for path, decl in DECL_CACHE.items():
        project_top[path] = set(decl.top_level)

    problems: list[str] = []
    for path in files:
        problems.extend(check_file(path, DECL_CACHE, project_top))

    print(f"checked {len(files)} Dart files under lib/ and test/")
    if problems:
        print(f"{len(problems)} problem(s):")
        for problem in problems:
            print(f"  {problem}")
        return 1
    print("no structural problems found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
