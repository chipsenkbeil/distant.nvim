local Destination = require('distant-core.destination')

describe('distant-core.destination.try_parse', function()
    it('should return the destintaion when successful', function()
        local d = Destination:try_parse('scheme://username:password@some.destination:1234')

        assert.are.same({
            scheme = 'scheme',
            username = 'username',
            password = 'password',
            host = 'some.destination',
            port = 1234,
        }, d)
    end)

    it('should yield nil if the destination is invalid', function()
        local d = Destination:try_parse('')
        assert.is_nil(d)

        local d = Destination:try_parse('scheme://')
        assert.is_nil(d)

        local d = Destination:try_parse(':')
        assert.is_nil(d)

        local d = Destination:try_parse('@')
        assert.is_nil(d)

        local d = Destination:try_parse('username@')
        assert.is_nil(d)

        local d = Destination:try_parse(':password@')
        assert.is_nil(d)

        local d = Destination:try_parse(':1234')
        assert.is_nil(d)

        local d = Destination:try_parse('some.destination:asdf')
        assert.is_nil(d)
    end)
end)
