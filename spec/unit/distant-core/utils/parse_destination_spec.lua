local utils = require('distant-core.utils')

describe('distant-core.utils.parse_destination', function()
    it('should support parsing just a host', function()
        local d = utils.parse_destination('some.destination')

        assert.are.same({
            scheme = nil,
            username = nil,
            password = nil,
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a host & port', function()
        local d = utils.parse_destination('some.destination:1234')

        assert.are.same({
            scheme = nil,
            username = nil,
            password = nil,
            host = 'some.destination',
            port = 1234,
        }, d)
    end)

    it('should support parsing a scheme & host', function()
        local d = utils.parse_destination('scheme://some.destination')

        assert.are.same({
            scheme = 'scheme',
            username = nil,
            password = nil,
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a username & host', function()
        local d = utils.parse_destination('username@some.destination')

        assert.are.same({
            scheme = nil,
            username = 'username',
            password = nil,
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a password & host', function()
        local d = utils.parse_destination(':password@some.destination')

        assert.are.same({
            scheme = nil,
            username = nil,
            password = 'password',
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a username & password & host', function()
        local d = utils.parse_destination('username:password@some.destination')

        assert.are.same({
            scheme = nil,
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a scheme & username & password & host', function()
        local d = utils.parse_destination('scheme://username:password@some.destination')

        assert.are.same({
            scheme = 'scheme',
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a username & password & host & port', function()
        local d = utils.parse_destination('username:password@some.destination:1234')

        assert.are.same({
            scheme = nil,
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = 1234,
        }, d)
    end)

    it('should support parsing a scheme & username & password & host & port', function()
        local d = utils.parse_destination('scheme://username:password@some.destination:1234')

        assert.are.same({
            scheme = 'scheme',
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = 1234,
        }, d)
    end)

    it('should yield nil if the destination is invalid', function()
        local d = utils.parse_destination('')
        assert.is.falsy(d)

        local d = utils.parse_destination('scheme://')
        assert.is.falsy(d)

        local d = utils.parse_destination(':')
        assert.is.falsy(d)

        local d = utils.parse_destination('@')
        assert.is.falsy(d)

        local d = utils.parse_destination('username@')
        assert.is.falsy(d)

        local d = utils.parse_destination(':password@')
        assert.is.falsy(d)

        local d = utils.parse_destination(':1234')
        assert.is.falsy(d)

        local d = utils.parse_destination('some.destination:asdf')
        assert.is.falsy(d)
    end)
end)
