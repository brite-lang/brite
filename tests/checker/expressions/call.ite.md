# Checker Test: `call`

## Errors
- (4:4-4:5) Can not call `f` because we have one argument but we need two.
  - (2:11-2:36) two arguments
- (4:6-4:10) Can not call `f` because a `Bool` is not an `Int`.
  - (2:18-2:21) `Int`
- (4:4-4:11) Can not change the type of `f()` because an `Int` is not a `Bool`.
  - (2:18-2:21) `Int`
  - (4:13-4:17) `Bool`
- (5:6-5:10) Can not call `f` because a `Bool` is not an `Int`.
  - (2:18-2:21) `Int`
- (5:12-5:16) Can not call `f` because a `Bool` is not an `Int`.
  - (2:26-2:29) `Int`
- (5:4-5:17) Can not change the type of `f()` because an `Int` is not a `Bool`.
  - (2:18-2:21) `Int`
  - (5:19-5:23) `Bool`
- (6:4-6:5) Can not call `f` because we have three arguments but we only need two.
  - (2:11-2:36) two arguments
- (6:6-6:10) Can not call `f` because a `Bool` is not an `Int`.
  - (2:18-2:21) `Int`
- (6:12-6:16) Can not call `f` because a `Bool` is not an `Int`.
  - (2:26-2:29) `Int`
- (6:4-6:23) Can not change the type of `f()` because an `Int` is not a `Bool`.
  - (2:18-2:21) `Int`
  - (6:25-6:29) `Bool`
- (8:10-8:14) Can not call `f` because a `Bool` is not an `Int`.
  - (2:26-2:29) `Int`
- (9:5-9:9) Can not call `f` because a `Bool` is not an `Int`.
  - (2:18-2:21) `Int`
- (11:3-11:5) Cannot call a `Num`.
- (12:3-12:5) Cannot call a `Num`.
- (13:3-13:5) Cannot call a `Num`.
- (14:3-14:5) Cannot call a `Num`.
- (14:6-14:10) Can not find `nope`.
- (15:3-15:5) Cannot call a `Num`.
- (15:6-15:10) Can not find `nope`.
- (15:12-15:16) Can not find `nope`.
- (18:3-18:4) Cannot call a `Num`.
  - (17:11-17:13) `Num`
- (19:3-19:4) Cannot call a `Num`.
  - (17:11-17:13) `Num`
- (20:3-20:4) Cannot call a `Num`.
  - (17:11-17:13) `Num`
- (21:3-21:4) Cannot call a `Num`.
  - (17:11-17:13) `Num`
- (21:5-21:9) Can not find `nope`.
- (22:3-22:4) Cannot call a `Num`.
  - (17:11-17:13) `Num`
- (22:5-22:9) Can not find `nope`.
- (22:11-22:15) Can not find `nope`.
- (24:3-24:7) Can not find `nope`.
- (25:3-25:7) Can not find `nope`.
- (25:8-25:12) Can not find `nope`.
- (26:3-26:7) Can not find `nope`.
- (26:8-26:12) Can not find `nope`.
- (26:14-26:18) Can not find `nope`.
- (28:44-28:45) Can not call `f` because a `Num` is not an `Int`.
  - (28:22-28:25) `Int`
- (28:47-28:48) Can not call `f` because a `Num` is not an `Int`.
  - (28:27-28:30) `Int`
- (31:12-31:16) Can not call `g` because an `Int` is not a `Bool`.
  - (28:22-28:25) `Int`
- (31:21-31:25) Can not call `g` because an `Int` is not a `Bool`.
  - (28:27-28:30) `Int`
- (31:29-31:33) Can not call `g` because a `Bool` is not an `Int`.
  - (28:35-28:38) `Int`
- (32:5-32:17) Can not call `g` because we have one argument but we need two.
  - (28:18-28:38) two arguments
- (33:5-33:23) Can not call `g` because we have three arguments but we only need two.
  - (28:18-28:38) two arguments
- (33:15-33:16) We need a type for `c`.
