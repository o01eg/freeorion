#include "ConditionParserImpl.h"


namespace parse {
    struct conditions_parser_grammar::Impl {
        Impl(conditions_parser_grammar& conditions_parser_grammar,
             const parse::lexer& tok,
             detail::Labeller& label
            ) :
            string_grammar(tok, label, conditions_parser_grammar)
        {}

        const parse::string_parser_grammar string_grammar;
    };

    conditions_parser_grammar::conditions_parser_grammar(
        const parse::lexer& tok,
        detail::Labeller& label
    ) :
        conditions_parser_grammar::base_type(start, "conditions_parser_grammar"),
        m_impl(std::make_unique<conditions_parser_grammar::Impl>(*this, tok, label))
    {
    }

    conditions_parser_grammar::~conditions_parser_grammar() = default;
}
