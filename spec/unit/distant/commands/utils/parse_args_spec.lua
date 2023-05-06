local utils = require('distant.commands.utils')

describe('distant.commands.utils.parse_args', function()
    it('should fail if quote is unclosed', function()
        assert.has.errors(function()
            utils.parse_args('"')
        end)
    end)

    it('should support empty string', function()
        local cmd = utils.parse_args('')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {})
    end)

    it('should support string of only whitespace', function()
        local cmd = utils.parse_args('    ')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, {})
    end)

    it('should support single word', function()
        local cmd = utils.parse_args('word')
        assert.are.same(cmd.args, { 'word' })
        assert.are.same(cmd.opts, {})
    end)

    it('should trim surrounding whitespace', function()
        local cmd = utils.parse_args('   word   ')
        assert.are.same(cmd.args, { 'word' })
        assert.are.same(cmd.opts, {})
    end)

    it('should support words separated by space', function()
        local cmd = utils.parse_args('two words')
        assert.are.same(cmd.args, { 'two', 'words' })
        assert.are.same(cmd.opts, {})
    end)

    it('should support key=value pair', function()
        local cmd = utils.parse_args('key=value')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, { key = 'value' })
    end)

    it('should support words and key=value pairs', function()
        local cmd = utils.parse_args('two k=v words k2=v2')
        assert.are.same(cmd.args, { 'two', 'words' })
        assert.are.same(cmd.opts, { k = 'v', k2 = 'v2' })
    end)

    it('should support quoted words', function()
        local cmd = utils.parse_args('"all in one item"')
        assert.are.same(cmd.args, { 'all in one item' })
        assert.are.same(cmd.opts, {})
    end)

    it('should support quoted words mixed in with words', function()
        local cmd = utils.parse_args('word "quoted words" another_word')
        assert.are.same(cmd.args, { 'word', 'quoted words', 'another_word' })
        assert.are.same(cmd.opts, {})
    end)

    it('should support quoted keys in key=value pairs', function()
        local cmd = utils.parse_args('"quoted key"=value')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, { ['quoted key'] = 'value' })
    end)

    it('should support quoted values in key=value pairs', function()
        local cmd = utils.parse_args('key="quoted value"')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, { key = 'quoted value' })
    end)

    it('should support quoted keys & values in key=value pairs', function()
        local cmd = utils.parse_args('"quoted key"="quoted value"')
        assert.are.same(cmd.args, {})
        assert.are.same(cmd.opts, { ['quoted key'] = 'quoted value' })
    end)

    it('should support expanding nested keys', function()
        local cmd = utils.parse_args('tbl.one=v1 "tbl.two.quoted three.four"=v2 k=v1.v2')
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
