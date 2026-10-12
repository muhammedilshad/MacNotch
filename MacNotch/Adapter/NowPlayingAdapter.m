// Reads the system-wide "Now Playing" state (Spotify, Music, YouTube in any browser, …).
//
// Since macOS 15.4 the private MediaRemote framework only answers Apple-signed processes, so
// the app loads this library into /usr/bin/perl through DynaLoader and talks to it over a pipe:
//
//   dn_stream  prints one JSON object per line whenever playback changes; exits when stdin closes.
//   dn_send    sends the command in $DN_COMMAND (2 play/pause, 4 next, 5 previous), or seeks to
//              $DN_SEEK seconds, and exits.
//
// Both are installed as Perl XSUBs, so they receive (PerlInterpreter *, CV *) and ignore them.

#import <AppKit/AppKit.h>
#include <dlfcn.h>

typedef void (*MRRegisterFunction)(dispatch_queue_t);
typedef void (*MRGetInfoFunction)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetIsPlayingFunction)(dispatch_queue_t, void (^)(BOOL));
typedef void (*MRGetClientFunction)(dispatch_queue_t, void (^)(id));
typedef NSString *(*MRClientStringFunction)(id);
typedef Boolean (*MRSendCommandFunction)(int, NSDictionary *);
typedef void (*MRSetElapsedTimeFunction)(double);

static MRRegisterFunction MRRegister;
static MRGetInfoFunction MRGetInfo;
static MRGetIsPlayingFunction MRGetIsPlaying;
static MRGetClientFunction MRGetClient;
static MRClientStringFunction MRClientBundleID;
static MRClientStringFunction MRClientParentBundleID;
static MRSendCommandFunction MRSendCommand;
static MRSetElapsedTimeFunction MRSetElapsedTime;

static BOOL LoadMediaRemote(void) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!handle) return NO;
    MRRegister = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    MRGetInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
    MRGetIsPlaying = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    MRGetClient = dlsym(handle, "MRMediaRemoteGetNowPlayingClient");
    MRClientBundleID = dlsym(handle, "MRNowPlayingClientGetBundleIdentifier");
    MRClientParentBundleID = dlsym(handle, "MRNowPlayingClientGetParentAppBundleIdentifier");
    MRSendCommand = dlsym(handle, "MRMediaRemoteSendCommand");
    MRSetElapsedTime = dlsym(handle, "MRMediaRemoteSetElapsedTime");
    return MRRegister && MRGetInfo && MRGetIsPlaying && MRSendCommand;
}

static NSString *lastLine;
static NSUInteger lastArtworkLength;
static NSUInteger lastArtworkHash;
static BOOL emitPending;

static void Write(NSDictionary *payload) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!json) return;
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static void Emit(NSDictionary *info, BOOL playing, NSString *bundleID) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"title"] = info[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: @"";
    payload[@"artist"] = info[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"";
    payload[@"album"] = info[@"kMRMediaRemoteNowPlayingInfoAlbum"] ?: @"";
    payload[@"playing"] = @(playing);
    payload[@"bundleID"] = bundleID ?: @"";
    NSNumber *duration = info[@"kMRMediaRemoteNowPlayingInfoDuration"];
    if (duration) payload[@"duration"] = duration;
    NSNumber *elapsed = info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"];
    if (elapsed) payload[@"elapsed"] = elapsed;
    // The elapsed time was measured at this moment; the app extrapolates from it using the rate.
    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    if ([timestamp isKindOfClass:NSDate.class]) payload[@"timestamp"] = @(timestamp.timeIntervalSince1970);
    NSNumber *rate = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
    if (rate) payload[@"rate"] = rate;

    // Artwork is only sent when it changes, to keep the pipe light.
    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    BOOL artworkChanged = artwork.length != lastArtworkLength || artwork.hash != lastArtworkHash;

    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingSortedKeys error:nil];
    NSString *line = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : nil;
    if (!artworkChanged && [line isEqualToString:lastLine]) return;
    lastLine = line;

    if (artworkChanged) {
        lastArtworkLength = artwork.length;
        lastArtworkHash = artwork.hash;
        payload[@"artwork"] = artwork.length ? [artwork base64EncodedStringWithOptions:0] : @"";
    }
    Write(payload);
}

static void Refresh(void) {
    dispatch_queue_t queue = dispatch_get_main_queue();
    MRGetInfo(queue, ^(NSDictionary *info) {
        MRGetIsPlaying(queue, ^(BOOL playing) {
            if (!MRGetClient || !MRClientBundleID) {
                Emit(info ?: @{}, playing, nil);
                return;
            }
            MRGetClient(queue, ^(id client) {
                NSString *bundleID = nil;
                if (client) {
                    bundleID = MRClientParentBundleID ? MRClientParentBundleID(client) : nil;
                    if (bundleID.length == 0) bundleID = MRClientBundleID(client);
                }
                Emit(info ?: @{}, playing, bundleID);
            });
        });
    });
}

/// Coalesces bursts of notifications into one refresh.
static void ScheduleRefresh(void) {
    if (emitPending) return;
    emitPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        emitPending = NO;
        Refresh();
    });
}

void dn_stream(void *interpreter, void *cv) {
    if (!LoadMediaRemote()) {
        Write(@{@"error": @"MediaRemote unavailable"});
        return;
    }
    MRRegister(dispatch_get_main_queue());
    for (NSString *name in @[@"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                             @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                             @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification"]) {
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) { ScheduleRefresh(); }];
    }

    // Quit as soon as the app goes away (its end of our stdin closes).
    dispatch_source_t input = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(input, ^{
        char buffer[256];
        if (read(STDIN_FILENO, buffer, sizeof buffer) <= 0) exit(0);
    });
    dispatch_resume(input);

    // Some players don't notify on every change, so poll gently as a backstop.
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC, NSEC_PER_SEC / 2);
    dispatch_source_set_event_handler(timer, ^{ Refresh(); });
    dispatch_resume(timer);

    CFRunLoopRun();
}

void dn_send(void *interpreter, void *cv) {
    if (!LoadMediaRemote()) return;
    const char *command = getenv("DN_COMMAND");
    const char *seek = getenv("DN_SEEK");
    if (seek && MRSetElapsedTime) {
        MRSetElapsedTime(atof(seek));
    } else if (command) {
        MRSendCommand(atoi(command), nil);
    } else {
        return;
    }
    // The command is delivered asynchronously; exiting at once can drop it.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, false);
}
