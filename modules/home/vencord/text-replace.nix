# regexRules for Vencord's TextReplace plugin.
#
# Rules are applied to outgoing messages in order. `id` is Vencord's own
# per-rule key and must stay stable, otherwise the plugin treats an edited
# rule as a new one.
[
  # Strip a trailing backslash that isn't part of an emoji shortcode.
  {
    "find" = "([^:])\\\\\\s*$";
    "replace" = "$1";
    "onlyIfIncludes" = "";
    "id" = "a9cae59b-78f5-478c-89c5-83e056ebe9d4";
  }

  # youtube.com/watch|embed|shorts -> youtu.be short form
  {
    "find" = "https?:\\/\\/(?:www\\.)?youtube\\.com\\/(?:watch\\?v=|embed\\/|shorts\\/)([\\w\\-]{11})";
    "replace" = "https://youtu.be/$1";
    "onlyIfIncludes" = "";
    "id" = "0fe41f58-40f5-4c81-904e-d6d470762672";
  }
  # ...and repair the query separator the rule above can leave behind.
  {
    "find" = "https:\\/\\/youtu.be\\/([\\w\\-]{11})&(.+)";
    "replace" = "https://youtu.be/$1?$2";
    "onlyIfIncludes" = "";
    "id" = "b8f2f595-f5ea-4148-8fa6-dbf94311aea2";
  }

  # Embed fixers: swap each host for a proxy that renders a real preview.
  {
    "find" =
      "https?:\\/\\/(?:www\\.)?instagram\\.com\\/(reels?|p|stories)(?!.*\\/audio\\b)(\\/[\\w\\.\\-]{11})[\\/\\w?&=]*";
    "replace" = "https://kkinstagram.com/$1$2";
    "onlyIfIncludes" = "";
    "id" = "5ed62ae3-7b0f-4bfe-a251-7bc2e19b0eaa";
  }
  # $1 carries the optional g./d./t. subdomain through to the proxy.
  {
    "find" =
      "https?:\\/\\/(?:www\\.)?((?:g|d|t)\\.)?(?:twitt(?:e|p)r|(?:fixup)?x)\\.com((\\/\\w+){3})[\\/\\w?&=]*";
    "replace" = "https://$1goyimx.com$2";
    "onlyIfIncludes" = "";
    "id" = "82de6567-2be9-4d14-83d5-e36bfaf83fe0";
  }
  {
    "find" = "https?:\\/\\/(?:www\\.)?(v(?:t|m)\\.)?tiktok\\.com((\\/[\\w@]+){3})[\\/\\-\\w?&=]*";
    "replace" = "https://$1tnktok.com$2";
    "onlyIfIncludes" = "";
    "id" = "ce78ff53-197b-49bf-b480-dd372e77d8d4";
  }
  {
    "find" =
      "https?:\\/\\/(?:www\\.|(old\\.))?reddit\\.com\\/r\\/(\\w+)\\/(comments|s)\\/(\\w+)[\\/\\-\\w?&=]*";
    "replace" = "https://$1rxddit.com/r/$2/$3/$4";
    "onlyIfIncludes" = "";
    "id" = "a1745df8-a321-4be3-ab82-4f31d539bdae";
  }

  # Drop tracking/slug tails from AniList links.
  {
    "find" = "https?:\\/\\/(?:www\\.)?anilist\\.co\\/(anime|manga|character)\\/(\\d+)[\\/\\-\\w?&=]*";
    "replace" = "https://anilist.co/$1/$2";
    "onlyIfIncludes" = "";
    "id" = "9c4268b4-7094-40e5-9d95-7409d1d9c155";
  }
]
