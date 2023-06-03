local Version = require('distant-core.version')

describe('distant-core.version', function()
    describe('parse', function()
        it('should throw an error if invalid semver string provided', function()
            -- Relaxed version
            assert.has_error(function() Version:parse('a') end)
            assert.has_no.errors(function() Version:parse('1') end)
            assert.has_no.errors(function() Version:parse('1.2') end)
            assert.has_error(function() Version:parse('1.2.a') end)
            assert.has_error(function() Version:parse('1.a.3') end)
            assert.has_error(function() Version:parse('a.2.3') end)
            assert.has_error(function() Version:parse('1.2.3-') end)
            assert.has_error(function() Version:parse('1.2.3-a..a') end)
            assert.has_error(function() Version:parse('1.2.3-ab|123') end)
            assert.has_error(function() Version:parse('1.2.3++') end)
            assert.has_error(function() Version:parse('1.2.3+ab|123') end)

            -- Strict version
            assert.has_error(function() Version:parse('a', { strict = true }) end)
            assert.has_error(function() Version:parse('1', { strict = true }) end)
            assert.has_error(function() Version:parse('1.2', { strict = true }) end)
            assert.has_error(function() Version:parse('1.2.a', { strict = true }) end)
            assert.has_error(function() Version:parse('1.a.3', { strict = true }) end)
            assert.has_error(function() Version:parse('a.2.3', { strict = true }) end)
            assert.has_error(function() Version:parse('1.2.3-', { strict = true }) end)
            assert.has_error(function() Version:parse('1.2.3-a..a', { strict = true }) end)
            assert.has_error(function() Version:parse('1.2.3-ab|123', { strict = true }) end)
            assert.has_error(function() Version:parse('1.2.3++', { strict = true }) end)
            assert.has_error(function() Version:parse('1.2.3+ab|123', { strict = true }) end)
        end)

        it('should successfully parse a semver in the form of 1.2.3', function()
            local version = Version:parse('1.2.3')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
            })
        end)

        it('should support parsing pre-release version', function()
            local version = Version:parse('1.2.3-alpha.4.--')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
                prerelease = { 'alpha', '4', '--' },
            })
        end)

        it('should support parsing build metadata', function()
            local version = Version:parse('1.2.3+1.2.3.20230602.text.--')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
                build = { '1', '2', '3', '20230602', 'text', '--' },
            })
        end)

        it('should support parsing pre-release version and build metadata', function()
            local version = Version:parse('1.2.3-alpha.4.--+1.2.3.20230602.text.--')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
                prerelease = { 'alpha', '4', '--' },
                build = { '1', '2', '3', '20230602', 'text', '--' },
            })
        end)
    end)

    describe('try_parse', function()
        it('should return nil if invalid semver string provided', function()
            -- Relaxed version
            assert.is_nil(Version:try_parse('a'))
            assert.is.truthy(Version:try_parse('1'))
            assert.is.truthy(Version:try_parse('1.2'))
            assert.is_nil(Version:try_parse('1.2.a'))
            assert.is_nil(Version:try_parse('a.2.3'))
            assert.is_nil(Version:try_parse('1.2.3-'))
            assert.is_nil(Version:try_parse('1.2.3-a..a'))
            assert.is_nil(Version:try_parse('1.2.3++'))

            -- Strict version
            assert.is_nil(Version:try_parse('a', { strict = true }))
            assert.is_nil(Version:try_parse('1', { strict = true }))
            assert.is_nil(Version:try_parse('1.2', { strict = true }))
            assert.is_nil(Version:try_parse('1.2.a', { strict = true }))
            assert.is_nil(Version:try_parse('1.a.3', { strict = true }))
            assert.is_nil(Version:try_parse('a.2.3', { strict = true }))
            assert.is_nil(Version:try_parse('1.2.3-', { strict = true }))
            assert.is_nil(Version:try_parse('1.2.3-a..a', { strict = true }))
            assert.is_nil(Version:try_parse('1.2.3++', { strict = true }))
        end)

        it('should successfully parse a semver in the form of 1.2.3', function()
            local version = Version:try_parse('1.2.3')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
            })
        end)

        it('should support parsing pre-release version', function()
            local version = Version:try_parse('1.2.3-alpha.4.--')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
                prerelease = { 'alpha', '4', '--' },
            })
        end)

        it('should support parsing build metadata', function()
            local version = Version:try_parse('1.2.3+1.2.3.20230602.text.--')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
                build = { '1', '2', '3', '20230602', 'text', '--' },
            })
        end)

        it('should support parsing pre-release version and build metadata', function()
            local version = Version:try_parse('1.2.3-alpha.4.--+1.2.3.20230602.text.--')
            assert.are.same(version, {
                major = 1,
                minor = 2,
                patch = 3,
                prerelease = { 'alpha', '4', '--' },
                build = { '1', '2', '3', '20230602', 'text', '--' },
            })
        end)
    end)

    describe('has_prerelease', function()
        it('should return true if contains a prerelease version', function()
            assert(Version:new({
                major = 1,
                minor = 2,
                patch = 3,
                prerelease = { 'alpha' },
            }):has_prerelease())

            assert(Version:new({
                major = 1,
                minor = 2,
                patch = 3,
                prerelease = { 'alpha', '1' },
            }):has_prerelease())
        end)

        it('should return false if does not contains a prerelease version', function()
            assert(not Version:new({
                major = 1,
                minor = 2,
                patch = 3,
            }):has_prerelease())
        end)
    end)

    describe('has_build', function()
        it('should return true if contains build metadata', function()
            assert(Version:new({
                major = 1,
                minor = 2,
                patch = 3,
                build = { '20230602' },
            }):has_build())
        end)

        it('should return false if does not contain build metadata', function()
            assert(not Version:new({
                major = 1,
                minor = 2,
                patch = 3,
            }):has_build())
        end)
    end)

    describe('inc', function()
        describe('major', function()
            it('should increment the major level and reset everything below', function()
                local version

                version = Version:parse('0.0.0')
                assert.are.same(version:inc('major'), {
                    major = 1,
                    minor = 0,
                    patch = 0,
                })

                version = Version:parse('0.0')
                assert.are.same(version:inc('major'), {
                    major = 1,
                    minor = 0,
                    patch = 0,
                })

                version = Version:parse('0')
                assert.are.same(version:inc('major'), {
                    major = 1,
                    minor = 0,
                    patch = 0,
                })

                version = Version:parse('1.2.3-alpha.4+12345')
                assert.are.same(version:inc('major'), {
                    major = 2,
                    minor = 0,
                    patch = 0,
                })
            end)
        end)

        describe('minor', function()
            it('should increment the minor level and reset everything below', function()
                local version

                version = Version:parse('0.0.0')
                assert.are.same(version:inc('minor'), {
                    major = 0,
                    minor = 1,
                    patch = 0,
                })

                version = Version:parse('0.0')
                assert.are.same(version:inc('minor'), {
                    major = 0,
                    minor = 1,
                    patch = 0,
                })

                version = Version:parse('0')
                assert.are.same(version:inc('minor'), {
                    major = 0,
                    minor = 1,
                    patch = 0,
                })

                version = Version:parse('1.2.3-alpha.4+12345')
                assert.are.same(version:inc('minor'), {
                    major = 1,
                    minor = 3,
                    patch = 0,
                })
            end)
        end)

        describe('patch', function()
            it('should increment the patch level and reset everything below', function()
                local version

                version = Version:parse('0.0.0')
                assert.are.same(version:inc('patch'), {
                    major = 0,
                    minor = 0,
                    patch = 1,
                })

                version = Version:parse('0.0')
                assert.are.same(version:inc('patch'), {
                    major = 0,
                    minor = 0,
                    patch = 1,
                })

                version = Version:parse('0')
                assert.are.same(version:inc('patch'), {
                    major = 0,
                    minor = 0,
                    patch = 1,
                })

                version = Version:parse('1.2.3-alpha.4+12345')
                assert.are.same(version:inc('patch'), {
                    major = 1,
                    minor = 2,
                    patch = 4,
                })
            end)
        end)

        describe('no level', function()
            it('should increment the patch level and reset everything below', function()
                local version

                version = Version:parse('0.0.0')
                assert.are.same(version:inc(), {
                    major = 0,
                    minor = 0,
                    patch = 1,
                })

                version = Version:parse('0.0')
                assert.are.same(version:inc(), {
                    major = 0,
                    minor = 0,
                    patch = 1,
                })

                version = Version:parse('0')
                assert.are.same(version:inc(), {
                    major = 0,
                    minor = 0,
                    patch = 1,
                })

                version = Version:parse('1.2.3-alpha.4+12345')
                assert.are.same(version:inc(), {
                    major = 1,
                    minor = 2,
                    patch = 4,
                })
            end)
        end)
    end)

    describe('cmp', function()
        --- lhs, rhs, expected
        local TESTS = {
            -- Major version comparison
            { '1',           '2',           -1 },
            { '2',           '1',           1 },
            { '1',           '1',           0 },

            -- Minor version comparison
            { '1.1',         '1.2',         -1 },
            { '1.2',         '1.1',         1 },
            { '1.1',         '1.1',         0 },

            -- Patch version comparison
            { '1.1.1',       '1.1.2',       -1 },
            { '1.1.2',       '1.1.1',       1 },
            { '1.1.1',       '1.1.1',       0 },

            -- Prerelease version comparison
            { '1-a',         '1',           -1 },
            { '1',           '1-a',         1 },
            { '1-a',         '1-a',         0 },
            { '1-1',         '1-2',         -1 },
            { '1-2',         '1-1',         1 },
            { '1-a',         '1-b',         -1 },
            { '1-b',         '1-a',         1 },
            { '1-1',         '1-a',         -1 },
            { '1-a',         '1-1',         1 },
            { '1-1',         '1-1.1',       -1 },
            { '1-1.1',       '1-1',         1 },

            -- Filling in missing minor & patch versions
            { '1',           '1.1',         -1 },
            { '1.1',         '1.1.1',       -1 },
            { '1.1',         '1',           1 },
            { '1.1.1',       '1.1',         1 },
            { '1',           '1.0.0',       0 },
            { '1.2',         '1.2.0',       0 },

            -- Build metadata does nothing
            { '1.2.3+build', '1.2.3+other', 0 },
            { '1.2.3+build', '1.2.3',       0 },
            { '1.2.3',       '1.2.3+build', 0 },
        }

        it('should properly compare and return precedence as -1 (lower), 0 (equal), 1 (higher)', function()
            for _, test in ipairs(TESTS) do
                local lhs, rhs, expected = unpack(test)
                local actual = Version:parse(lhs):cmp(Version:parse(rhs))
                assert(
                    actual == expected,
                    ('Expected %d, got %d: "%s":cmp("%s")'):format(
                        expected, actual, lhs, rhs
                    )
                )
            end
        end)
    end)

    describe('compatible', function()
        --- version, requirement, expected
        local TESTS = {
            -- With a non-zero major version
            { '1.2.3',       '1',           true },
            { '1.2.3',       '1.2',         true },
            { '1.2.3',       '1.2.2',       true },
            { '1.2.3',       '1.2.3',       true },
            { '1.2.3',       '1.2.4',       false },
            { '1.2.3',       '1.3',         false },
            { '1.2.3',       '2',           false },

            -- With a non-zero minor version
            { '0.2.3',       '0',           true },
            { '0.2.3',       '0.2',         true },
            { '0.2.3',       '0.2.2',       true },
            { '0.2.3',       '0.2.3',       true },
            { '0.2.3',       '0.2.4',       false },
            { '0.2.3',       '0.3',         false },
            { '0.2.3',       '1',           false },

            -- With a non-zero patch version
            { '0.0.3',       '0',           true },
            { '0.0.3',       '0.0',         true },
            { '0.0.3',       '0.0.2',       false },
            { '0.0.3',       '0.0.3',       true },
            { '0.0.3',       '0.0.4',       false },
            { '0.0.3',       '0.1',         false },
            { '0.0.3',       '1',           false },

            -- Special handling for all zeros
            { '0.0.1',       '0',           true },
            { '0.1.0',       '0',           true },
            { '0.1.1',       '0',           true },
            { '1.0.0',       '0',           false },
            { '0.0.1',       '0.0',         true },
            { '0.1.0',       '0.0',         false },
            { '0.1.1',       '0.0',         false },
            { '1.0.0',       '0.0',         false },
            { '0.0.1',       '0.0.0',       false },
            { '0.1.0',       '0.0.0',       false },
            { '0.1.1',       '0.0.0',       false },
            { '1.0.0',       '0.0.0',       false },

            -- With a prerelease version
            -- (will have lower precedence than normal)
            { '1.2.3',       '1.2.2-a',     true },
            { '1.2.3',       '1.2.3-a',     true },
            { '1.2.3',       '1.2.4-a',     false },
            { '1.2.2-a',     '1.2.3',       false },
            { '1.2.3-a',     '1.2.3',       false },
            { '1.2.4-a',     '1.2.3',       true },
            { '1.2.3-a',     '1.2.3-a',     true },
            { '1.2.3-a',     '1.2.3-b',     false },
            { '1.2.3-b',     '1.2.3-a',     true },
            { '1.2.3-1.2.2', '1.2.3-1.2.3', false },
            { '1.2.3-1.2.3', '1.2.3-1.2.3', true },
            { '1.2.3-1.2.4', '1.2.3-1.2.3', true },
            { '1.2.3-1',     '1.2.3-a',     false },
            { '1.2.3-a',     '1.2.3-1',     true },
            { '1.2.3-1',     '1.2.3-1.1',   false },
            { '1.2.3-1.1',   '1.2.3-1',     true },

            -- Build metadata does nothing
            { '1.2.2',       '1.2.3+build', false },
            { '1.2.3',       '1.2.3+build', true },
            { '1.2.4',       '1.2.3+build', true },
        }

        it('should determine if versions are compatible', function()
            for _, test in ipairs(TESTS) do
                local lhs, rhs, expected = unpack(test)
                local actual = Version:parse(lhs):compatible(Version:parse(rhs))
                assert(
                    actual == expected,
                    ('Expected %s, got %s: "%s":compatible("%s")'):format(
                        expected, actual, lhs, rhs
                    )
                )
            end
        end)
    end)

    describe('prerelease_string', function()
        it('should return nil if there is no prerelease', function()
            assert.is_nil(Version:new({ major = 1 }):prerelease_string())
            assert.is_nil(Version:new({ major = 1, prerelease = {} }):prerelease_string())
        end)

        it('should return a string representing the prerelease', function()
            assert.are.equal(Version:new({ major = 1, prerelease = { 'a', 'b' } }):prerelease_string(), 'a.b')
        end)
    end)

    describe('build_string', function()
        it('should return nil if there is no prerelease', function()
            assert.is_nil(Version:new({ major = 1 }):build_string())
            assert.is_nil(Version:new({ major = 1, build = {} }):build_string())
        end)

        it('should return a string representing the prerelease', function()
            assert.are.equal(Version:new({ major = 1, build = { 'a', 'b' } }):build_string(), 'a.b')
        end)
    end)

    describe('as_string', function()
        it('should convert the version to its semver string form', function()
            local version

            version = Version:new({ major = 1 })
            assert.are.equal(version:as_string(), '1')

            version = Version:new({ major = 1, minor = 2 })
            assert.are.equal(version:as_string(), '1.2')

            version = Version:new({ major = 1, minor = 2, patch = 3 })
            assert.are.equal(version:as_string(), '1.2.3')

            version = Version:new({ major = 1, patch = 3 })
            assert.are.equal(version:as_string(), '1.0.3')

            version = Version:new({ major = 1, prerelease = { 'a' } })
            assert.are.equal(version:as_string(), '1-a')

            version = Version:new({ major = 1, prerelease = { 'a', '1' } })
            assert.are.equal(version:as_string(), '1-a.1')

            version = Version:new({ major = 1, build = { 'a' } })
            assert.are.equal(version:as_string(), '1+a')

            version = Version:new({ major = 1, build = { 'a', '1' } })
            assert.are.equal(version:as_string(), '1+a.1')

            version = Version:new({ major = 1, prerelease = { 'a' }, build = { 'b' } })
            assert.are.equal(version:as_string(), '1-a+b')

            version = Version:new({ major = 1, prerelease = { 'a', '1' }, build = { 'b', '2' } })
            assert.are.equal(version:as_string(), '1-a.1+b.2')
        end)
    end)

    describe('metamethods', function()
        it('should support < for version', function()
            assert.is.truthy(Version:parse('1') < Version:parse('2'))
            assert.is.falsy(Version:parse('2') < Version:parse('2'))
            assert.is.falsy(Version:parse('3') < Version:parse('2'))
        end)

        it('should support <= for version', function()
            assert.is.truthy(Version:parse('1') <= Version:parse('2'))
            assert.is.truthy(Version:parse('2') <= Version:parse('2'))
            assert.is.falsy(Version:parse('3') <= Version:parse('2'))
        end)

        it('should support == for version', function()
            assert.is.falsy(Version:parse('1') == Version:parse('2'))
            assert.is.truthy(Version:parse('2') == Version:parse('2'))
            assert.is.falsy(Version:parse('3') == Version:parse('2'))
        end)

        it('should support >= for version', function()
            assert.is.falsy(Version:parse('1') >= Version:parse('2'))
            assert.is.truthy(Version:parse('2') >= Version:parse('2'))
            assert.is.truthy(Version:parse('3') >= Version:parse('2'))
        end)

        it('should support > for version', function()
            assert.is.falsy(Version:parse('1') > Version:parse('2'))
            assert.is.falsy(Version:parse('2') > Version:parse('2'))
            assert.is.truthy(Version:parse('3') > Version:parse('2'))
        end)

        it('should support casting to string', function()
            local version = Version:parse('1.2.3')
            assert.are.equal(tostring(version), '1.2.3')
        end)
    end)
end)
