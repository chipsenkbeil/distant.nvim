local command = require('distant.command')

describe('command.parse_input', function()
    it('should fail if quote is unclosed', function()
        assert.has.errors(function()
            command.parse_input('"')
        end)
    end)

    it('should support empty string', function()
        local cmd = command.parse_input('')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {})
    end)

    it('should support string of only whitespace', function()
        local cmd = command.parse_input('    ')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {})
    end)

    it('should support single word', function()
        local cmd = command.parse_input('word')
        assert.are.same(cmd.args, {'word'})
        assert.are.same(cmd.opts, {})
    end)

    it('should trim surrounding whitespace', function()
        local cmd = command.parse_input('   word   ')
        assert.are.same(cmd.args, {'word'})
        assert.are.same(cmd.opts, {})
    end)

    it('should support words separated by space', function()
        local cmd = command.parse_input('two words')
        assert.are.same(cmd.args, {'two', 'words'})
        assert.are.same(cmd.opts, {})
    end)

    it('should support key=value pair', function()
        local cmd = command.parse_input('key=value')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {key = 'value'})
    end)

    it('should support words and key=value pairs', function()
        local cmd = command.parse_input('two k=v words k2=v2')
        assert.are.same(cmd.args, {'two', 'words'})
        assert.are.same(cmd.opts, {k = 'v', k2 = 'v2'})
    end)

    it('should support quoted words', function()
        local cmd = command.parse_input('"all in one item"')
        assert.are.same(cmd.args, {'all in one item'})
        assert.are.same(cmd.opts, {})
    end)

    it('should support quoted words mixed in with words', function()
        local cmd = command.parse_input('word "quoted words" another_word')
        assert.are.same(cmd.args, {'word', 'quoted words', 'another_word'})
        assert.are.same(cmd.opts, {})
    end)

    it('should support quoted keys in key=value pairs', function()
        local cmd = command.parse_input('"quoted key"=value')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {['quoted key'] = 'value'})
    end)

    it('should support quoted values in key=value pairs', function()
        local cmd = command.parse_input('key="quoted value"')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {key = 'quoted value'})
    end)

    it('should support quoted keys & values in key=value pairs', function()
        local cmd = command.parse_input('"quoted key"="quoted value"')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {['quoted key'] = 'quoted value'})
    end)

    it('should support expanding nested keys', function()
        local cmd = command.parse_input('tbl.one=v1 "tbl.two.quoted three.four"=v2 k=v1.v2')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {
            tbl = {
                one = 'v1',
                two = {
                    ['quoted three'] = {
                        four = 'v2'
                    }
                },
            },
            k = 'v1.v2',
        })
    end)
end)
