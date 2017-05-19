# GitHubCommenters Plugin for Movable Type

* Authors: Easun Lee <https://easun.org> 
* Copyright (C) 2017 EasunLee.
* License: MIT License


## Overview

The GitHubCommenters plugin for Movable Type allows commenters to login
and comment to your blog using their GitHub account. Upon login, a user
will be created localy for this GitHub user, with their name and public
profile picture.

## Prerequisites

* Movable Type 4.3 or higher
* JSON (bundled with MT)

## Installation

1. Unpack the GitHubCommenters archive.
3. Copy the contents of GitHubCommenters/mt-static into /path/to/mt/mt-static/
4. Copy the contents of GitHubCommenters/plugins into /path/to/mt/plugins/
5. Login to your Movable Type Dashboard which will install the plugin.
6. Navigate to the Plugin Settings on the blog you wish to allow GitHub commenters.
7. Click on `Register a new OAuth application` link, and create your app on GitHub
    1. Modify any as name,homepage as you like, except `Authorization callback URL`. This URL should point to the `<$mt:CommentScript $>` of the site which will be implementing GitHub Connect (this is usually named as `mt-comments.cgi` and can be changed by `mt-config.cgi`, e.g. `https://yousite.name/path/to/mt/mt-comments.cgi`).
    2. Press `Register application` button and you will get the API Key(`Client ID`) and Secret(`Client Secret`) form GitHub.

8. Within your blog's Plugin Settings, input the API Key(`Client ID`) and Secret(`Client Secret`) from GitHub.
9. Enable "GitHub" as a Registration Authentication Method via `Preferences` -> `Registration` and ensure that User Registration is allowed.
10. Republish your blog for all of the changes to take effect.

