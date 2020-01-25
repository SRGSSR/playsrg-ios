# Remote configuration

The proprietary project can be configured remotely using [Firebase](https://firebase.google.com/). All primitive parameters (strings, numbers, booleans, JSON) from the `ApplicationConfiguration.json` file can be overridden. 

Some parameters are mandatory and others are optional. All applications are provided with a default configuration, available even when the Firebase service could not be queried (e.g. if no network connection is initially available).

## Behavior

If a parameter is overridden in the Firebase console, its value will be used, otherwise the local value will be used instead. If you want to disable an optional parameter for which a local value is available, you must therefore define an override for it in the Firebase console, providing no value.

The remote configuration has a validity of 15 minutes (30 seconds when debugging and in nightly builds), and is applied when the application wakes up from the background.

If a remote configuration is found to be invalid (usually a mandatory parameter is missing), the application will ignore it and continue with the previous valid configuration.

## Available parameters

A wide list of parameters are available. Some parameters support multiple comma-separated values.

### Homepages (videos, audios, livestreams)

* `videoHomeSections` (optional, string, multiple): The sections to be displayed on the videos homepage, in the order they must appear.
* `audioHomeSections` (optional, string, multiple): for each radio channels, the sections to be displayed on their audio homepage in the order they must appear.
* `liveHomeSections` (optional, string, multiple): The sections to be displayed on the live homepage, in the order they must appear.



Available home section values are:

* with radio channel uid support:
   * `radioAllShows`: All available shows.
   * `radioLatest`: The latest audios.
   * `radioLatestEpisodes`: The latest episodes.
   * `radioLatestVideos`: The latest videos.
   * `radioLive`: Access to the livestreams.
   * `radioMostPopular`: The most popular audios.
   * `radioMyListShows`: Shows from "My list".
   * `radioShowsAccess`: A-Z and By date access buttons.

* others:

   * `tvEvents`: Event modules. 
   * `tvLatest`: The latest medias.
   * `tvLive`: Access to the livestreams.
   * `tvLiveCenter`: Access to SwissTXT livestreams.
   * `tvMyListShows`: Shows from "My list".
   * `tvScheduledLivestreams`: Access to scheduled livestreams.
   * `tvShowsAccess`: A-Z and By date access buttons.
   * `tvSoonExpiring`: Soon expiring videos.
   * `tvTopics`: Topics.
   * `tvTrending`: Trending medias and editorial picks. See `tvTrendingEpisodesOnly` and `tvTrendingEditorialLimit` options.
   * `tvMostPopular`: The most popular videos.

Here are UI options:

* `tvFeaturedHomeSectionHeaderHidden` (optional, boolean): If set to `true`, featured media lists will not display any header on the TV homepage.
* `moduleColorsDisabled` (optional, boolean): If set to `true`, module lists won't display colors.
* `radioFeaturedHomeSectionHeaderHidden` (optional, boolean): If set to `true`, featured media lists will not display any header on the radio homepages.
* `moduleDefaultLinkColor` (mandatory, string):  Hex color of title medias in module lists.
* `moduleDefaultTextColor` (mandatory, string):  Hex color of subtitle medias in module lists.
* `topicHeaders` (optional, JSON): A JSON array of JSON dictionaries describing topics headers, and made of the following keys:
	 * `uid` (mandatory, string): The unique identifier of the topic.
    * `imageURL` (mandatory, string): The topic image URL (compatible with image scaling syntax).
    * `imageTitle` (optional, string): The image title.
    * `imageCopyright` (optional, string): The image copyright.

Here are content options:

* `tvTrendingEpisodesOnly` (optional, boolean): If set to `true`, `tvTrending` only returns episodes.
* `tvTrendingEditorialLimit` (optional, number): The maximum number of editorial recommendations returned by `tvTrending`. If not set, all are returned.
* `topicSections` (optional, string, multiple): The sections to be displayed when opening a topic. If none is provided, latest medias are displayed. Available values are:
   * `latest`: The latest medias.
   * `mostPopular`: The most popular medias
* `topicSectionsWithSubtopics` (optional, string, multiple): The sections to be displayed when opening a topic with subtopics. If none is provided, only subtopics are displayed. Available values are the same as `topicSections`.

Broadcast informations:

* `tvChannels` (optional, JSON): A JSON array of JSON dictionaries describing TV channel configuration, and made of the following keys:
    * `uid` (mandatory, string): The unique identifier of the TV channel.
    * `name` (mandatory, string): The TV channel name.
    * `resourceUid` (mandatory, string): Local unique identifier for referencing resources related to the channel.
* `radioChannels` (optional, JSON): A JSON array of JSON dictionaries describing radio channel configuration, and made of the following keys:
    * `uid` (mandatory, string): The unique identifier of the radio channel.
    * `name` (mandatory, string): The radio channel name.
    * `resourceUid` (mandatory, string): Local unique identifier for referencing resources related to the channel.
    * `color` (mandatory, string): The radio channel primary hex color. Used as navigation bar background color.
    * `homeSections` (optional, string, multiple): The sections to be displayed on the radio channel homepage. See `audioHomeSections` for available values. If omitted, the global `audioHomeSections` setting is used instead (in which case this value is required).
    * `titleColor` (optional, string): Hex color of the text displayed within the navigation bar (should provide sufficient contrast with `color`). If omitted, white.
    * `hasDarkStatusBar` (optional, boolean): `true` iff the status bar should be dark for this channel. If omitted, `false`.
    * `numberOfLivePlaceholders` (optional, number): The number of placeholders to be displayed while content is being loaded. By If omitted, 1.
* `videoRadioChannelUids` (optional, string, multiple): The ordered list of radio channel unique identifiers supporting videos. Identifiers must be in the `radioChannels`.`uid` list.
### Search

* `searchSettingsHidden` (optional, boolean): Set to `true` to hide support for search settings.
* `searchSettingSubtitledHidden` (optional, boolean): Set to `true` to hide the subtitled option in the search settings.
* `showsSearchHidden ` (optional, boolean): Set to `true` to hide show search results.

### Player

* `minimumSocialViewCount` (optional, number): The threshold under which social view counts will not be displayed. If omitted, 0.
* `prefersDRM` (optional, boolean, **ended: 2.9.6**): Set to `true` to favor DRM streams over non-DRM ones. If omitted, `false`.

### Functionalities

* `downloadsHintsHidden` (optional, boolean): If set to `true`, hints will not be displayed in lists for medias which can be downloaded.
* `moreEpisodesHidden` (optional, boolean): If set to `true`, the option to display more episodes for a media will not be available from the long-press and peek menus.
* `googleCastReceiverIdentifier` (optional, string): Identifier of the Google Cast receiver to use. If not set, the default Google Cast receiver is used.
* `appStoreProductIdentifier` (mandatory, number): Application product identifier on the AppStore.
* `continuousPlaybackPlayerViewTransitionDuration` (optional, number): Duration in seconds for continuous playback when the player view is displayed. If empty, continuous playback is disabled; if equal to 0, upcoming media playback starts immediately.
* `continuousPlaybackForegroundTransitionDuration` (optional, number): Duration in seconds for continuous playback when the application runs in foreground and the player view is not displayed. If empty, continuous playback is disabled; if equal to 0, upcoming media playback starts immediately.
* `continuousPlaybackBackgroundTransitionDuration` (optional, number): Duration in seconds for continuous playback when the application runs in background. If empty, continuous playback is disabled; if equal to 0, upcoming media playback starts immediately.
* `hiddenOnboardings` (optional, string, multiple): Identifier list of onboardings which must be hidden.

### History

* `historyServiceURL` (optional, string): The URL of the history service.
* `historySynchronizationInterval` (optional, number): Duration in seconds for history synchronization. If omitted, defaults to 30 seconds. Miminum value is 10 seconds.

### URLs

* `betaTestingURL` (optional, string): The URL of the page where beta testers can register.
* `feedbackURL` (optional, string): The URL of the feedback form. Optional since version 2.9.1.
* `dataProtectionURL` (optional, string): The URL of the data protection information page.
* `impressumURL` (optional, string): The URL of the impressum page. If none is provided, the corresponding menu entry will not be displayed. 
* `middlewareURL` (mandatory, string): The URL of the Play application middleware.
* `playURL` (mandatory, string): The base URL of the Play portal, used when building sharing URLs.
* `showURLPath` (optional, string, not used since 2.8): The (relative) path to the `playURL` when building show sharing URLs.
* `sourceCodeURL` (optional, string); The URL where the application source code can be found.
* `termsAndConditionsURL` (optional, string): The URL of the terms and conditions page.
* `whatsNewURL` (mandatory, string): The URL at which the update information can be retrieved.

### General parameters

* `businessUnit` (mandatory, string): The identifier of the business unit.
* `pageSize` (optional, number): The page size to use for media lists in general, 20 if not set.
* `tvNumberOfLivePlaceholders` (optional, number): Used as a hint to display a better number of TV live placeholders while content is being loaded. Should match the expected number of TV channels. If not set, defaults to 3.
* `voiceOverLanguageCode` (optional, string): The code of the language associated with the application. If set, this language is used when reading texts for accessibility purposes, otherwise the device language is used.
* `subtitleAvailabilityHidden` (optional, boolean): Set to `true` to hide the subtitle availability setting.
* `audioDescriptionAvailabilityHidden` (optional, boolean): Set to `true` to hide audio description availability setting.


### Analytics

* `comScoreVirtualSite` (mandatory, string): The comScore virtual site to send events to.
* `netMetrixIdentifier` (mandatory, string): The NetMetrix application identifier.