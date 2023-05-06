local Destination = require('distant-core.destination')

describe('distant-core.destination.parse', function()
    it('should support parsing just a host', function()
        local d = Destination:parse('some.destination')

        assert.are.same({
            scheme = nil,
            username = nil,
            password = nil,
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a host & port', function()
        local d = Destination:parse('some.destination:1234')

        assert.are.same({
            scheme = nil,
            username = nil,
            password = nil,
            host = 'some.destination',
            port = 1234,
        }, d)
    end)

    it('should support parsing a scheme & host', function()
        local d = Destination:parse('scheme://some.destination')

        assert.are.same({
            scheme = 'scheme',
            username = nil,
            password = nil,
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a username & host', function()
        local d = Destination:parse('username@some.destination')

        assert.are.same({
            scheme = nil,
            username = 'username',
            password = nil,
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a password & host', function()
        local d = Destination:parse(':password@some.destination')

        assert.are.same({
            scheme = nil,
            username = nil,
            password = 'password',
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a username & password & host', function()
        local d = Destination:parse('username:password@some.destination')

        assert.are.same({
            scheme = nil,
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a scheme & username & password & host', function()
        local d = Destination:parse('scheme://username:password@some.destination')

        assert.are.same({
            scheme = 'scheme',
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = nil,
        }, d)
    end)

    it('should support parsing a username & password & host & port', function()
        local d = Destination:parse('username:password@some.destination:1234')

        assert.are.same({
            scheme = nil,
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = 1234,
        }, d)
    end)

    it('should support parsing a scheme & username & password & host & port', function()
        local d = Destination:parse('scheme://username:password@some.destination:1234')

        assert.are.same({
            scheme = 'scheme',
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = 1234,
        }, d)
    end)

    it('should throw an error if destination is empty', function()
        assert.has.error(function()
            Destination:parse('')
        end)
    end)

    it('should throw an error if destination is just a scheme (no host)', function()
        assert.has.error(function()
            Destination:parse('scheme://')
        end)
    end)

    it('should throw an error if destination is just a : (no host)', function()
        assert.has.error(function()
            Destination:parse(':')
        end)
    end)

    it('should throw an error if destination is just a @ (no host)', function()
        assert.has.error(function()
            Destination:parse('@')
        end)
    end)

    it('should throw an error if destination is just a username (no host)', function()
        assert.has.error(function()
            Destination:parse('username@')
        end)
    end)

    it('should throw an error if destination is just a password (no host)', function()
        assert.has.error(function()
            Destination:parse(':password@')
        end)
    end)

    it('should throw an error if destination is just a port (no host)', function()
        assert.has.error(function()
            Destination:parse(':1234')
        end)
    end)

    it('should throw an error if destination has a non-numeric port', function()
        assert.has.error(function()
            Destination:parse('some.destination:asdf')
        end)
    end)
end)
