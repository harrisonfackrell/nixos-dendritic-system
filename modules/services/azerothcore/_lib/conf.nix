# Config-value machinery for the AzerothCore module: the module-naming
# helpers plus the option type, flattening and rendering used to turn the
# `*Config` attribute-set options into the flat "Key = Value" .conf files
# the servers read. Pure: depends only on `lib` (and `builtins`), never on
# the module's options or `pkgs`.
{ lib }:
let
    # AzerothCore module naming helpers. A module's directory is
    # modules/<name>/ and its conf file is conf/<base>.conf.dist, where
    # <base> is <name> with the conventional "mod-" prefix stripped
    # (mod-playerbots -> playerbots). The core's CMake bakes the list of
    # conf basenames (CONFIG_FILE_LIST) from the modules' *.conf.dist files
    # and the worldserver loads <prefix>/etc/modules/<base>.conf at runtime,
    # so the installed conf must be named after <base>, not <name>.
    stripMod = name: lib.removePrefix "mod-" name;
    capitalize = s:
        if lib.stringLength s == 0 then ""
        else lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (lib.stringLength s - 1) s;
    # The basename (incl. .conf) of a module's conf file.
    # (Explicit null-check: Nix 2.34 removed the `or` operator, and in
    # older Nix `null or X` still evaluates to null, so `or` cannot be
    # used for a null-defaulted option.)
    confNameOf = name: entry:
        if entry.confName == null then
            stripMod name + ".conf"
        else
            entry.confName;

    # ---------------------------------------------------------------------
    # Config value type + rendering (shared by core and module confs).
    #
    # One key's value: a string or an integer, or a nested attrset of the
    # same to any depth. Nested attrsets are flattened to the dot-separated
    # keys AzerothCore's flat Config::ParseFile expects, so both of these
    # render identically:
    #   worldserverConfig."Visibility.Distance" = 100;
    #   worldserverConfig.Visibility.Distance = 100;
    #   -> Visibility.Distance = 100
    #
    # The element type is a hand-built option type (lib.mkOptionType), the
    # same mechanism nixpkgs uses for bespoke option types (see
    # config/sysctl.nix, the prometheus smokeping exporter, ibus, ...):
    # - check is deliberately permissive (AzerothCore rejects unknown/bogus
    #   keys at its own startup, and renderConf stringifies whatever
    #   survives);
    # - merge implements the per-key deep merge so that, combined with the
    #   per-key lib.mkDefault declarations done in `config` below, a host
    #   overriding one key of a nested set keeps the default keys of the
    #   siblings (scalars use last-wins).
    # ---------------------------------------------------------------------
    confElemType = lib.mkOptionType {
        name = "confValue";
        description = "a server config value: a string, an integer, or a nested set of these";
        descriptionClass = "composite";
        check = x:
            builtins.isAttrs x
            || lib.types.str.check x
            || lib.types.int.check x;
        merge = loc: defs:
            let
                unwrap = d:
                    let v = d.value; in
                    if builtins.isAttrs v && v ? _type && v._type == "override" then
                        { value = v.content; priority = v.priority; }
                    else
                        { value = v; priority = lib.defaultOverridePriority; };
                deepMergeTwo = a: b:
                    if builtins.isAttrs a && builtins.isAttrs b then
                        lib.recursiveUpdate a b
                    else
                        b;
            in
            builtins.foldl' deepMergeTwo { }
                (lib.map (u: u.value)
                    (builtins.sort (x: y: y.priority > x.priority)
                        (lib.map unwrap defs)));
    };
    confValueType = lib.types.attrsOf confElemType;

    # Flatten a (possibly nested) key/value attrset to a flat attrset whose
    # keys are dot-joined paths. Nested attrsets become dot-separated key
    # names (the only "nested" concept AzerothCore's flat Config::ParseFile
    # has); everything else is stringified, since every conf value is
    # ultimately a string.
    #   flattenConfValues { a = 1; b = { c = "x"; }; }
    #     == { a = "1"; b.c = "x"; }
    flattenEntries = attrs:
        builtins.concatMap (name:
            let
                v = attrs.${name};
            in
            if v != null && builtins.isAttrs v then
                map (kv: { name = "${name}.${kv.name}"; value = toString kv.value; })
                    (flattenEntries v)
            else
                [ { inherit name; value = toString v; } ]
        ) (builtins.attrNames attrs);
    flattenConfValues = attrs: builtins.listToAttrs (flattenEntries attrs);

    # Render a key/value attrset into the "Key = Value" lines the servers
    # expect. Keys are emitted in a stable, sensible order (the
    # most-frequently-tuned ones first) with any unknown keys appended
    # alphabetically, so the generated file is predictable and diffs stay
    # readable when a host adds or overrides keys.
    confOrder = [
        "RealmServerPort"
        "WorldServerPort"
        "DataDir"
        "LoginDatabaseInfo"
        "WorldDatabaseInfo"
        "CharacterDatabaseInfo"
        "PlayerbotsDatabaseInfo"
        "LogsDir"
        "TempDir"
        "MySQLExecutable"
        "SourceDirectory"
    ];
    orderedNames = attrs:
        let
            present = builtins.attrNames attrs;
            known = builtins.filter (k: builtins.elem k present) confOrder;
            unknown = builtins.sort builtins.lessThan
                (builtins.filter (k: !builtins.elem k confOrder) present);
        in
        known ++ unknown;
    renderConf = name: attrs:
        let
            flat = flattenConfValues attrs;
        in
        ''
            # --- generated by nixos-dendritic-system (azerothcore: ${name}) ---
            ${lib.concatStringsSep "\n" (lib.map (k: "${k} = ${flat.${k}}") (orderedNames flat))}
        '';
in
{
    inherit
        stripMod
        capitalize
        confNameOf
        confElemType
        confValueType
        renderConf;
}
