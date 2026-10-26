#!/usr/bin/env python3

# This file ends in ".pl" because it used to be a perl script, and updating all of
# the client projects and OS mastering rules is not worth the effort.

import os
import re
import sys
import shutil
import filecmp
import argparse
import tempfile

from ast import literal_eval

MIN_PYTHON = (3, 7) #Required for ordered dictionaries as default
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

# The build script will embed the DSL content here, otherwise we build it at runtime
dslContent = None
dslContent = """
# Platform DSL
# This describes all our platforms, and versions
# It is used to autogenerate defines for availability markup
# By generating everything form a common source we guarantee consistency

# platform parameters (positional)
# 1: Platform short name (used for command line arguments to availability.pl)
# 2: Stylized name (used for platform aware dyld version strings)
# 3: Macro name (used by default in macro expansions)
# Optionals:
# cmd_aliases: comma separated list os additional aliases for use with availability.pl
# dyld_version_define_name: an override for the name that appears in legacy (non-platform) dyld version numbers. Defaults to macro name
# availability_aliases: comma separated set of alias that can be used in API_AVAILABLE() markup functions instead of the platform name
# min_max_define_name: an override for the name that appears _VERSION_MIN_REQUIRED/_VERSION_MAX_ALLOWED macros. Defaults to macro name
# -short_version_numbers: Boolean to enable shorter form version numbers
# availability_deprecation_define_name: an override for the name that appears __API_TO_BE_DEPRECATED_ macros. Defaults to macro name
# platform_define_name: an override for the name that appears PLATFORM_ macros. Defaults to macro name
# version_define_name: an override for the name that appears version defines (__MAC_10_1, etc). Defaults to macro name
# ios_implicit_min: Sets an implicit ios min value for iOS derived platforms
# bleached: Boolean to mark a platform as bleached from the pulic SDKs

platform    macos               macOS 		MACOS			cmd_aliases=macosx,osx		dyld_version_define_name=MACOSX	min_max_define_name=MAC_OS_X	availability_aliases=macosx -short_version_numbers availability_deprecation_define_name=MACOS version_define_name=MAC -supports_legacy_environment_defines
version     macos               10.0
version     macos               10.1
version     macos               10.2
version     macos               10.3
version     macos               10.4
version     macos               10.5
version     macos               10.6
version     macos               10.7
platform    ios                 iOS         IPHONE		dyld_version_define_name=IOS	min_max_define_name=IPHONE_OS platform_define_name=IOS availability_deprecation_define_name=IOS -supports_legacy_environment_defines
variant		ios					iosmac		MACCATALYST	availability_aliases=macCatalyst
version     ios                 2.0
version     ios                 2.1
version     ios                 2.2
version     ios                 3.0
version     ios                 3.1
version     ios                 3.2
version     ios                 4.0
version     ios                 4.1
version     ios                 4.2
version     ios                 4.3
version     ios                 5.0
set         fall_2011           2011.9.1	0.0
version     ios                 5.1
version     macos               10.8
version     ios                 6.0
set         fall_2012           2012.9.1	0.0
version     macos               10.9
version     ios                 6.1
version     ios                 7.0
set         fall_2013           2013.9.1	0.0
version     macos               10.10
version     ios                 7.1
version     ios                 8.0
set         fall_2014           2014.9.1	0.0
platform    watchos             watchOS     WATCHOS		ios_implicit_min=9.0	min_max_define_name=WATCH_OS -supports_legacy_environment_defines
version     watchos             1.0
version     macos               10.10.2
version     macos               10.10.3
version     macos               10.11
version     ios                 8.1
version     ios                 8.2
version     ios                 8.3
version     ios                 8.4
version     ios                 9.0
platform    tvos                tvOS        TVOS		cmd_aliases=appletvos	ios_implicit_min=9.0 min_max_define_name=TV_OS -supports_legacy_environment_defines
version     tvos                9.0
version     watchos             2.0
set         fall_2015           2015.9.1	0.0
version     macos               10.11.2
version     macos               10.11.3
version     macos               10.11.4
version     macos               10.12
version     ios                 9.1
version     ios                 9.2
version     ios                 9.3
version     ios                 10.0
version     watchos             2.1
version     watchos             2.2
version     tvos                9.1
version     tvos                9.2
version     tvos                10.0
version     watchos             3.0
set         fall_2016           2016.9.1	0.0
version     macos               10.12.1
version     macos               10.12.2
version     macos               10.12.4
version     ios                 10.1
version     ios                 10.2
version     ios                 10.3
version     tvos                10.0.1
version     tvos                10.1
version     tvos                10.2
version     watchos             3.1
version     watchos             3.1.1
version     watchos             3.2
version     macos               10.13
version     ios                 11.0
version     tvos                11.0
version     watchos             4.0
platform    bridgeos            bridgeOS	BRIDGEOS	ios_implicit_min=11.0 min_max_define_name=BRIDGE_OS
version     bridgeos            2.0
set         fall_2017           2017.9.1	0.0
version     macos               10.13.1
version     macos               10.13.2
version     ios                 11.1
version     ios                 11.2
version     tvos                11.1
version     tvos                11.2
version     watchos             4.1
version     watchos             4.2
set         winter_2017         2017.18.1	0.0
version     macos               10.13.4
version     ios                 11.3
version     tvos                11.3
version     watchos             4.3
set         spring_2018         2018.3.1	0.0
version     ios                 11.4
version     tvos                11.4
version     macos               10.14
version     ios                 12.0
version     tvos                12.0
version     watchos             5.0
version     bridgeos            3.0
set         fall_2018           2018.9.1	0.0
version     macos               10.14.1
version     ios                 12.1
version     tvos                12.1
version     watchos             5.1
version     bridgeos            3.1
set         late_fall_2018      2018.16.21	0.0
version     macos               10.14.4
version     ios                 12.2
version     tvos                12.2
version     watchos             5.2
version     bridgeos            3.4
set         spring_2019         2019.3.1	0.0
version     ios                 12.3
version     tvos                12.3
version     macos               10.14.5
set         summer_2019         2019.6.1	0.0
version     macos               10.14.6
version     ios                 12.4
version     tvos                12.4
version     watchos             5.3
set         late_summer_2019    2019.7.21	0.0
version     macos               10.15
version     ios                 13.0
version     tvos                13.0
version     watchos             6.0
version     bridgeos            4.0
platform    driverkit           driverkit    DRIVERKIT
version     driverkit           19.0
set         fall_2019           2019.9.1	0.0
version     ios                 13.1
set         autumn_2019         2019.9.2	0.0
version     macos               10.15.1
version     ios                 13.2
version     tvos                13.2
version     watchos             6.1
version     bridgeos            4.1
set         late_fall_2019      2019.16.21	0.0
version     ios                 13.3
version     tvos                13.3
set         winter_2019         2019.18.1	0.0
version     macos               10.15.4
version     ios                 13.4
version     tvos                13.4
version     watchos             6.2
set         spring_2020         2020.3.1	0.0
version     ios                 13.5
set         late_spring_2020    2020.4.21	0.0
version     ios                 13.6
set         summer_2020         2020.6.1	0.0
version     ios                 13.7
set         late_summer_2020    2020.7.21	0.0
version     macos               10.16
version     ios                 14.0
version     tvos                14.0
version     watchos             7.0
version     bridgeos            5.0
version     driverkit           20.0
set         fall_2020           2020.9.1	0.0
version     ios                 14.1
version     tvos                14.1
version     watchos             7.1
version     ios                 14.2
version     tvos                14.2
set         late_fall_2020      2020.16.21	0.0
version     macos               11.0
version     ios                 14.3
version     tvos                14.3
version     watchos             7.2
version     bridgeos            5.1
version     macos               11.1
set         winter_2020         2020.18.1	0.0
version     ios                 14.5
version     tvos                14.5
version     watchos             7.3
version     watchos             7.4
version     bridgeos            5.3
version     macos               11.3
set         spring_2021         2021.3.1	0.0
version     macos               11.4
version     macos               11.5
version     macos               11.6
version     ios                 14.4
version     ios                 14.5
version     ios                 14.6
version     ios                 14.7
version     ios                 14.8
version     tvos                14.6
version     tvos                14.7
version     watchos             7.5
version     watchos             7.6
version     macos               12.0
version     ios                 15.0
version     tvos                15.0
version     watchos             8.0
version     bridgeos            6.0
version     driverkit           21.0
set         fall_2021           2021.9.1    0.0
version     ios                 15.1
version     tvos                15.1
version     watchos             8.1
set         late_fall_2021      2021.16.21  0.0
version     macos               12.1
version     ios                 15.2
version     tvos                15.2
version     watchos             8.3
version     bridgeos            6.2
set         winter_2021         2021.18.01  0.0
version     macos               12.2
version     ios                 15.3
version     tvos                15.3
version     watchos             8.4
set         late_winter_2021    2021.18.21  0.0
version     macos               12.3
version     ios                 15.4
version     tvos                15.4
version     watchos             8.5
version     bridgeos            6.4
set         spring_2022         2022.3.1    0.0
version     macos               12.4
version     ios                 15.5
version     tvos                15.5
version     watchos             8.6
version     bridgeos            6.5
set         late_spring_2022    2022.4.15   0.0
version     macos               12.5
version     ios                 15.6
version     tvos                15.6
version     watchos             8.7
version     bridgeos            6.6
set         summer_2022         2022.6.1    0.0
# Security updates that shipped after final normal SU
version     macos               12.6
version     macos               12.7
version     watchos             8.8
version     ios                 15.7
version     ios                 15.8
version     macos               13.0
version     ios                 16.0
version     tvos                16.0
version     watchos             9.0
version     bridgeos            7.0
version     driverkit           22.0
set         fall_2022           2022.9.1    0.0
version     macos               13.1
version     ios                 16.1
version     tvos                16.1
version     watchos             9.1
version     bridgeos            7.1
set         late_fall_2022      2022.16.21  0.0
version     macos               13.1
version     watchos             9.2
version     tvos                16.2
version     ios                 16.2
version     bridgeos            7.1
set         2022_SU_C           2022.33.0   0.0
version     macos               13.2
version     watchos             9.3
version     tvos                16.3
version     ios                 16.3
version     bridgeos            7.2
set         2022_SU_D           2022.34.0   0.0
version     driverkit           22.4
version     macos               13.3
version     ios                 16.4
version     tvos                16.4
version     watchos             9.4
version     bridgeos            7.3
set         2022_SU_E           2022.35.0   22.4.0
version     driverkit           22.5
version     macos               13.4
version     ios                 16.5
version     tvos                16.5
version     watchos             9.5
version     bridgeos            7.4
set         2022_SU_F           2022.36.0   22.5.0
version     driverkit           22.6
version     macos               13.5
version     ios                 16.6
version     tvos                16.6
version     watchos             9.6
version     bridgeos            7.6
set         2022_SU_G           2022.37.0   22.6.0
# Security updates shipped after 2022_SU_G
version     macos               13.6
version     ios                 16.7
version     macos               14.0
version     ios                 17.0
version     tvos                17.0
version     watchos             10.0
version     bridgeos            8.0
version     driverkit           23.0
set         fall_2023           2023.9.1    23.0.0
platform    visionos            visionOS    VISIONOS      min_max_define_name=VISION_OS   cmd_aliases=xros availability_aliases=xros ios_implicit_min=17.1
version     visionos            1.0
version     macos               14.1
version     ios                 17.1
version     tvos                17.1
version     watchos             10.1
version     bridgeos            8.1
version     driverkit           23.1
set         2023_SU_B           2023.12.1    23.1.0
version     macos               14.2
version     ios                 17.2
version     tvos                17.2
version     watchos             10.2
version     bridgeos            8.2
version     driverkit           23.2
set         2023_SU_C           2023.13.1    23.2.0
version     macos               14.3
version     ios                 17.3
version     tvos                17.3
version     watchos             10.3
version     bridgeos            8.3
version     driverkit           23.3
set         2023_SU_D           2023.14.1    23.3.0
#ifndef __OPENSOURCE__
platform    exclavekit          exclavekit  EXCLAVEKIT -unversioned
version     visionos            1.1
version     macos               14.4
version     ios                 17.4
version     tvos                17.4
version     watchos             10.4
version     bridgeos            8.4
version     driverkit           23.4
set         2023_SU_E           2023.15.1    23.4.0
version     visionos            1.2
version     macos               14.5
version     ios                 17.5
version     tvos                17.5
version     watchos             10.5
version     bridgeos            8.5
version     driverkit           23.5
set         2023_SU_F           2023.16.1    23.5.0
version     visionos            1.3
version     macos               14.6
version     ios                 17.6
version     tvos                17.6
version     watchos             10.6
version     bridgeos            8.6
version     driverkit           23.6
set         2023_SU_G           2023.17.1    23.6.0
version     visionos            2.0
version     macos               15.0
version     ios                 18.0
version     tvos                18.0
version     watchos             11.0
version     bridgeos            9.0
version     driverkit           24.0
set         fall_2024           2024.0.0    24.0
#endif
"""

class VersionSetDSL:
    def __init__(self, data):   self.parsedDSL = self.Parser(data)
    def sets(self):             return self.parsedDSL.version_sets
    def platforms(self):        return self.parsedDSL.platforms

    class Version:
        vers = ""
        def __init__(self, vers):
            self.vers = vers
        def hex(self):
            major = 0
            minor = 0
            revision = 0
            match = re.match(r"^(\d+)(?:.(\d+))?(?:.(\d+))?$", self.vers)
            assert match  is not None
            if (match.group(1)): major = int(match.group(1))
            if (match.group(2)): minor = int(match.group(2))
            if (match.group(3)): revision = int(match.group(3))
            return f"0x00{major :02x}{minor :02x}{revision :02x}"
        def decimal(self, macosFormat):
            major = 0
            minor = 0
            revision = 0
            result = ""
            match = re.match(r"^(\d+)(?:.(\d+))?(?:.(\d+))?$", self.vers)
            assert match is not None
            if (match.group(1)): major = int(match.group(1))
            if (match.group(2)): minor = int(match.group(2))
            if (match.group(3)): revision = int(match.group(3))
            if macosFormat and major == 10 and minor <= 9: result = f"{major}{minor :01}{revision :01}"
            else: result = f"{major}{minor :02}{revision :02}"
            return result.rjust(6)
        def symbol(self):
            match = re.match(r"^(\d+)(?:.(\d+))?(?:.(\d+))?$", self.vers)
            assert match is not None
            if match.group(3) and match.group(3) != 0: return f"{match.group(1)}_{match.group(2)}_{match.group(3)}"
            if match.group(2): return f"{match.group(1)}_{match.group(2)}"
            if match.group(1): return match.group(1)
            sys.exit("Illegal version")
        def string(self): return self.vers
    class Variant:
        def __init__(self, name, macroName, **optionals):
            self.name                                   = name
            self.availability_aliases                   = []
            self.availability_deprecation_define_name   = macroName
            if "availability_aliases" in optionals:
                self.availability_aliases = optionals["availability_aliases"].split(',')
    class Platform:
        def __init__(self, name, stylizedName, macroName, **optionals):
            # Default values
            self.name                                   = name
            self.stylized_name                          = stylizedName
            self.availability_deprecation_define_name   = macroName
            self.min_max_define_name                    = macroName
            self.availability_define_prefix             = f"__{macroName}_"
            self.platform_define                        = f"PLATFORM_{macroName}"
            self.dyld_version_define_name               = f"DYLD_{macroName}_VERSION_"
            self.versions                               = []
            self.variants                               = []
            self.cmd_aliases                            = []
            self.availability_aliases                   = []
            self.ios_compatility_version                = None
            self.versioned                              = not optionals.get("unversioned", False)
            self.short_version_numbers                  = optionals.get("short_version_numbers", False)
            self.bleached                               = optionals.get("bleached", False)
            self.target_os_name                         = optionals.get("target_os_name", name)
            self.supports_legacy_environment_defines    = optionals.get("supports_legacy_environment_defines", False)
            if "platform_define_name" in optionals:
                self.platform_define = f"PLATFORM_{optionals['platform_define_name']}"
            if "cmd_aliases" in optionals:
                self.cmd_aliases = optionals["cmd_aliases"].split(',')
            if "availability_aliases" in optionals:
                self.availability_aliases = optionals["availability_aliases"].split(',')
            if "dyld_version_define_name" in optionals:
                self.dyld_version_define_name = f'DYLD_{optionals["dyld_version_define_name"]}_VERSION_'
            if "min_max_define_name" in optionals:
                self.min_max_define_name = optionals["min_max_define_name"]
            if "ios_implicit_min" in optionals:
                self.ios_compatility_version = VersionSetDSL.Version(optionals["ios_implicit_min"])
            if "availability_deprecation_define_name" in optionals:
                self.availability_deprecation_define_name = optionals["availability_deprecation_define_name"]
            if "version_define_name" in optionals:
                self.availability_define_prefix = f"__{optionals['version_define_name']}_"
        def add_version(self, version): return self.versions.append(version);
        def add_variant(self, variant): return self.variants.append(variant);
    class Parser:
        platforms       = {}
        version_sets    = []
        def __init__(self, data):
            for line in data.splitlines():
                line = line.strip().split('#',1)[0]
                if not line:
                    continue
                parts = line.split()
                args = []
                kwargs = {}
                for dsl_arg in parts:
                    if '=' in dsl_arg:
                        k, v = dsl_arg.split('=', 1)
                        kwargs[k] = v
                    elif dsl_arg[0] == "-":
                        kwargs[dsl_arg[1:]] = True
                    else:
                        args.append(dsl_arg)
                getattr(self, parts[0])(*args[1:], **kwargs)
        def set(self, name, version, uversion):
            platforms = {}
            for (platformName, platform) in self.platforms.items():
                if platform.versioned:
                    platforms[platformName] = platform.versions[-1]
            version_set                 = {}
            version_set["name"]         = name
            version_set["version"]      = VersionSetDSL.Version(version)
            version_set["platforms"]    = platforms
            self.version_sets.append(version_set)
            # TODO add error checking for version decrease
        def version(self, platform, version):
            if platform in self.platforms: self.platforms[platform].add_version(VersionSetDSL.Version(version))
            else:
                print(f"Unknown platform \"{platform}\"")
                exit(-1)
            # TODO add error checking for version decrease
        def platform(self, name, stylizedName, macroName, **optionals):
            self.platforms[name] = VersionSetDSL.Platform(name, stylizedName, macroName, **optionals)
        def variant(self, platform, name, macroName, **optionals):
            # print(f"PLATFORM {platform}\nNAME {name}\n)
            if platform in self.platforms:
                self.platforms[platform].add_variant(VersionSetDSL.Variant(name, macroName, **optionals))
            else:
                print(f"Unknown platform \"{platform}\"")
                exit(-1)

if not dslContent:
    uversion = os.getenv('RC_DARWIN_KERNEL_VERSION')
    dslContent = ""
    with open(f"{os.path.abspath(os.path.dirname(sys.argv[0]))}/availability.dsl", 'r') as f:
        for line in f.readlines():
            dslContent += line
            # We do this here instead of in the DSL parser because filtering the output in the DSL parser would 
            # require storing the parsed DSL structures or being able to regenerate the DSL. Both are doable, but
            # not worth the effort at this time
            parts = line.split()
            if uversion and parts and parts[0] == "set" and parts[3] == uversion:
                break
versions = VersionSetDSL(dslContent)

def print_sets():
    print("---")
    for set in versions.sets():
        print(f'{set["name"]}:')
        for os, osVersion in sorted(set["platforms"].items()):
            print(f' {os}: "{osVersion.string()}"')

def print_versions(platform):
    print(" ".join([version.string() for version in versions.platforms()[platform].versions]))

class Preprocessor:
    def __init__(self, inputFile, outputFile):
        bufferedOutput = ""
        with tempfile.NamedTemporaryFile('w') as tmp:
            with open(inputFile, 'r') as input:
                for line in input.readlines():
                    match = re.match(r"^(?:#|//)\s+@@(.*)\((.*)\)@@", line)
                    if match:
                        args = []
                        optionals = {}
                        if match.group(2):
                            for arg in match.group(2).split(','):
                                if '=' in arg:
                                    k, v = arg.split('=', 1)
                                    optionals[k] = v
                                else:
                                    args.append(arg)
                            getattr(self, match.group(1))(tmp, *args, **optionals)
                        else: getattr(self, match.group(1))(tmp)
                    else: tmp.write(line)
            tmp.flush()
            shutil.copymode(inputFile, tmp.name)
            if (not os.path.exists(outputFile)) or (not filecmp.cmp(tmp.name, outputFile)):
                shutil.copy(tmp.name, outputFile)
    def INSERT_DSL_CONTENT(self, output):
        output.write("dslContent = \"\"\"\n")
        output.write(dslContent)
        output.write("\"\"\"\n")
    def VERSION_MAP(self, output):
        sets = []
        for set in versions.sets():
            set_string = ", ".join(sorted({".{} = {}".format(os,osVersion.hex()) for (os,osVersion) in set["platforms"].items()}))
            sets.append("\t{{ .set = {}, {} }}".format(set["version"].hex(), set_string))
        platform_string = "\n".join(["    uint32_t {} = 0;".format(name) for name in versions.platforms().keys()])  
        output.write("""
#include <set>
#include <array>
namespace dyld3 {{
struct __attribute__((visibility("hidden"))) VersionSetEntry {{
    uint32_t set = 0;
{}
    bool operator<(const uint32_t& other) const {{
        return set < other;
    }}
}};

static const std::array<VersionSetEntry, {}> sVersionMap = {{{{
{}
}}}};
}};
""".format(platform_string, len(sets), ",\n".join(sets)))
    def DYLD_HEADER_VERSIONS(self, output):
        for (name,platform) in versions.platforms().items():
            for version in platform.versions:
                output.write(f"#define {platform.dyld_version_define_name + version.symbol() : <48}{version.hex()}\n");
            output.write("\n")
        for set in versions.sets():
            set_string = " / ".join(sorted({"{} {}".format(os,osVersion.string()) for(os,osVersion) in set["platforms"].items()}))
            output.write("// dyld_{}_os_versions => {}\n".format(set["name"], set_string))
            output.write("#define dyld_{}_os_versions".format(set["name"]).ljust(56, ' '))
            output.write("({{ (dyld_build_version_t){{0xffffffff, {}}}; }})\n\n".format(set["version"].hex()))
        for (name,platform) in versions.platforms().items():
            for version in platform.versions:
                output.write("#define dyld_platform_version_{}_{}".format(platform.stylized_name, version.symbol()).ljust(56, ' '))
                output.write("({{ (dyld_build_version_t){{{}, {}{}}}; }})\n".format(platform.platform_define, platform.dyld_version_define_name, version.symbol()))
            output.write("\n")
            # self.AVAILABILITY_VERSION_DEFINES_PLATFORM(output, platform)
    def ALIAS_VERSION_MACROS(self, output, platformString, newName, oldName, **optionals):
        minVersion =  literal_eval(optionals.get("minVersion", "0x00000000"))
        maxVersion =  literal_eval(optionals.get("maxVersion", "0xFFFFFFFF"))
        platform = versions.platforms()[platformString];
        for version in platform.versions:
            if literal_eval(version.hex()) < minVersion: continue
            if literal_eval(version.hex()) >= maxVersion: continue
            output.write(f'#define {newName + version.symbol() : <48} {oldName + version.symbol()}\n')
    def AVAILABILITY_DEFINES(self, output):
        for platformString in versions.platforms():
            platform = versions.platforms()[platformString];
            if platform.bleached:
                output.write(f"#ifndef __APPLE_BLEACH_SDK__\n")
            output.write(f"#ifndef __API_TO_BE_DEPRECATED_{platform.availability_deprecation_define_name}\n")
            output.write(f"#define __API_TO_BE_DEPRECATED_{platform.availability_deprecation_define_name} 100000\n")
            output.write(f"#endif\n");
            for variant in platform.variants:
                output.write(f"#ifndef __API_TO_BE_DEPRECATED_{variant.availability_deprecation_define_name}\n")
                output.write(f"#define __API_TO_BE_DEPRECATED_{variant.availability_deprecation_define_name} 100000\n")
                output.write(f"#endif\n");
            if platform.bleached:
                output.write(f"#endif /* __APPLE_BLEACH_SDK__ */\n")
            output.write(f"\n");
    def AVAILABILITY_VERSION_DEFINES(self, output):
        for platformString in versions.platforms():
            short = platform = versions.platforms()[platformString].short_version_numbers
            platform = versions.platforms()[platformString];
            for version in platform.versions:
                output.write(f"#define {platform.availability_define_prefix + version.symbol() : <48}{version.decimal(short)}\n")
            output.write(f"/* {platform.availability_define_prefix}_NA is not defined to a value but is used as a token by macros to indicate that the API is unavailable */\n\n")
    def AVAILABILITY_MIN_MAX_DEFINES(self, output):
        for platformString in versions.platforms():
            platform = versions.platforms()[platformString];
            if not platform.versioned:
                continue
            if platform.bleached:
                output.write(f"#ifndef __APPLE_BLEACH_SDK__\n")
            output.write(f"#ifndef __{platform.min_max_define_name}_VERSION_MIN_REQUIRED\n")
            output.write(f"    #if defined(__has_builtin) && __has_builtin(__is_target_os)\n")
            output.write(f"        #if __is_target_os({platform.target_os_name})\n")
            output.write(f"            #define __{platform.min_max_define_name}_VERSION_MIN_REQUIRED __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__\n")
            output.write(f"            #define __{platform.min_max_define_name}_VERSION_MAX_ALLOWED {platform.availability_define_prefix + platform.versions[-1].symbol()}\n")
            if platform.ios_compatility_version:
                output.write(f"            /* for compatibility with existing code.  New code should use platform specific checks */\n")
                output.write(f"            #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_{platform.ios_compatility_version.symbol()}\n")
            output.write(f"        #endif\n")
            if platform.supports_legacy_environment_defines:
                output.write(f"    #elif  __ENVIRONMENT_{platform.min_max_define_name}_VERSION_MIN_REQUIRED__ \n")
                output.write(f"        #define __{platform.min_max_define_name}_VERSION_MIN_REQUIRED __ENVIRONMENT_{platform.min_max_define_name}_VERSION_MIN_REQUIRED__\n")
                output.write(f"        #define __{platform.min_max_define_name}_VERSION_MAX_ALLOWED {platform.availability_define_prefix + platform.versions[-1].symbol()}\n")
                if platform.ios_compatility_version:
                    output.write(f"        /* for compatibility with existing code.  New code should use platform specific checks */\n")
                    output.write(f"        #define __IPHONE_OS_VERSION_MIN_REQUIRED __IPHONE_{platform.ios_compatility_version.symbol()}\n")
            output.write(f"    #endif /*  __has_builtin(__is_target_os) && __is_target_os({platform.target_os_name}) */\n")
            output.write(f"#endif /* __{platform.min_max_define_name}_VERSION_MIN_REQUIRED */\n")
            if platform.bleached:
                output.write(f"#endif /* __APPLE_BLEACH_SDK__ */\n")
            output.write("\n")
    def AVAILABILITY_PLATFORM_DEFINES(self, output):
        def writeDefines(displayName, realName, hasVersions):
            if hasVersions:
                output.write(f"   #define __API_AVAILABLE_PLATFORM_{displayName}(x) {realName},introduced=x\n")
                output.write(f"   #define __API_DEPRECATED_PLATFORM_{displayName}(x,y) {realName},introduced=x,deprecated=y\n")
            output.write(f"   #define __API_UNAVAILABLE_PLATFORM_{displayName} {realName},unavailable\n")
        output.write(f"#if defined(__has_feature) && defined(__has_attribute)\n")
        output.write(f" #if __has_attribute(availability)\n")
        for platformString in versions.platforms():
            platform = versions.platforms()[platformString];
            if platform.bleached:
                output.write(f"#ifndef __APPLE_BLEACH_SDK__\n")
            writeDefines(platformString, platformString, platform.versioned)
            for alias in platform.availability_aliases:
                writeDefines(alias, platformString, platform.versioned)
            for variant in platform.variants:
                writeDefines(variant.name, variant.name, platform.versioned)
                for alias in variant.availability_aliases:
                    writeDefines(alias, variant.name, platform.versioned)
            if platform.bleached:
                output.write(f"#endif /* __APPLE_BLEACH_SDK__ */\n")
        output.write(f" #endif /* __has_attribute(availability) */\n")
        output.write(f"#endif /* defined(__has_feature) && defined(__has_attribute) */\n")
    def AVAILABILITY_MACRO_IMPL(self, output, prefix, dispatcher, **optionals):
        count = len(versions.platforms())
        for platformString in versions.platforms():
            platform = versions.platforms()[platformString]
            count = count + len(platform.variants)
        platformList    = []
        argList         = []
        argPrefix       = ""
        if "args" in optionals:
            argList     = optionals["args"].split(",")
            argPrefix   = f"{optionals['args']},"
        for i in range(0, count):
            platformList.append(f"arg{i}")
            output.write(f"    #define {prefix}{i}({argPrefix}{','.join(platformList)}) {' '.join([f'{dispatcher}({argPrefix}{x})' for x in platformList])}\n")   
        output.write(f"    #define {prefix}_GET_MACRO({','.join([f'_{x}' for x in range(0, count+len(argList))])},NAME,...) NAME\n");
    def AVAILABILITY_MACRO_INTERFACE(self, output, name, macroName, **optionals):
        scoped_availablity = False
        if "scoped_availablity" in optionals and optionals["scoped_availablity"] == "TRUE":
            scoped_availablity=True
        count = len(versions.platforms())
        for platformString in versions.platforms():
            platform = versions.platforms()[platformString]
            count = count + len(platform.variants)
        argList = ','.join([f'{macroName}{x}' for x in reversed(range(0, count))])
        if "argCount" in optionals:
            argList = argList + (",0" * int(optionals["argCount"]))
        if scoped_availablity:
            output.write(f'    #define {name}_BEGIN(...) _Pragma("clang attribute push") {macroName}_GET_MACRO(__VA_ARGS__,{argList},0)(__VA_ARGS__)\n')
            output.write(f'    #define {name}_END _Pragma("clang attribute pop")\n')
        else:
            output.write(f"    #define {name}(...) {macroName}_GET_MACRO(__VA_ARGS__,{argList},0)(__VA_ARGS__)\n")

parser = argparse.ArgumentParser()
group = parser.add_mutually_exclusive_group()
for (name, platform) in versions.platforms().items():
    group.add_argument("--{}".format(name), default=False, action='store_true', help="Prints all SDK versions defined for {}".format(name))
    for alias in platform.cmd_aliases:
        group.add_argument("--{}".format(alias), dest=name, default=False, action='store_true', help="Alias for --{}".format(name))
group.add_argument("--sets",                                default=False, action='store_true', help='Prints all YAML for all defined version sets')
group.add_argument("--preprocess",                          nargs=2,                            help=argparse.SUPPRESS)
args = parser.parse_args()

if args.sets:                                   print_sets();
elif args.preprocess:                           Preprocessor(args.preprocess[0], args.preprocess[1]);
else:
    for platform in versions.platforms().keys():
        if getattr(args, platform, None):
            print_versions(platform)
            parser.exit(0)
    parser.print_help()
    parser.exit(2)

