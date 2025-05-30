#include "Parse.h"

#include "ParseImpl.h"
#include "ValueRefParser.h"
#include "ConditionParserImpl.h"
#include "MovableEnvelope.h"
#include "../universe/ValueRef.h"
#include "../util/Directories.h"

#include "PythonParserImpl.h"
#include "ValueRefPythonParser.h"
#include "ConditionPythonParser.h"
#include "EnumPythonParser.h"
#include "SourcePythonParser.h"

#include <boost/phoenix.hpp>

#include <boost/python/import.hpp>
#include <boost/python/raw_function.hpp>

#define DEBUG_PARSERS 0
#if DEBUG_PARSERS
namespace std {
    inline ostream& operator<<(ostream& os, const std::map<std::string, std::unique_ptr<ValueRef::ValueRef<double>>>&)
    { return os; }
    inline ostream& operator<<(ostream& os, const std::map<std::string, parse::detail::MovableEnvelope<ValueRef::ValueRef<double>>>&)
    { return os; }
}
#endif

namespace {
    using start_rule_payload = std::map<std::string, std::unique_ptr<ValueRef::ValueRef<double>>>;
    using start_rule_signature = void(start_rule_payload&);

    struct grammar : public parse::detail::grammar<
        start_rule_signature,
        boost::spirit::qi::locals<std::map<std::string, parse::detail::value_ref_payload<double>>>>
    {
        grammar(const parse::lexer& tok,
                const std::string& filename,
                const parse::text_iterator first, const parse::text_iterator last) :
            grammar::base_type(start),
            condition_parser(tok, label),
            string_grammar(tok, label, condition_parser),
            double_rules(tok, label, condition_parser, string_grammar)
        {
            namespace phoenix = boost::phoenix;
            namespace qi = boost::spirit::qi;

            using phoenix::insert;
            using phoenix::construct;

            qi::_1_type _1;
            qi::_2_type _2;
            qi::_3_type _3;
            qi::_4_type _4;
            qi::_a_type _a;
            qi::_r1_type _r1;
            qi::_val_type _val;
            qi::_pass_type _pass;
            qi::omit_type omit_;
            //const boost::phoenix::function<parse::detail::deconstruct_movable> deconstruct_movable_;

            stat
                = ( omit_[tok.Statistic_]
                >   label(tok.name_)    > tok.string
                >   label(tok.value_)   > double_rules.expr
                  ) [ _val = construct<std::pair<std::string, parse::detail::value_ref_payload<double>>>(_1, _2) ]
                ;

            start
                =   (+stat [ insert(_a, _1) ])
                [ _r1 = phoenix::bind(&parse::detail::OpenEnvelopes<std::string, ValueRef::ValueRef<double>>, _a, _pass) ]
                ;

            stat.name("Double Statistic ValueRef");

#if DEBUG_PARSERS
            debug(stat);
#endif

            qi::on_error<qi::fail>(start, parse::report_error(filename, first, last, _1, _2, _3, _4));
        }

        using stat_rule = parse::detail::rule<
            std::pair<std::string, parse::detail::value_ref_payload<double>> ()
            >;

        using start_rule = parse::detail::rule<
            start_rule_signature,
            boost::spirit::qi::locals<std::map<std::string, parse::detail::value_ref_payload<double>>>
            >;

        parse::detail::Labeller label;
        parse::conditions_parser_grammar condition_parser;
        const parse::string_parser_grammar string_grammar;
        parse::double_parser_rules      double_rules;
        stat_rule   stat;
        start_rule  start;
    };

    boost::python::object py_insert_empire_statistics_(start_rule_payload& stats_, const boost::python::tuple& args,
                                                       const boost::python::dict& kw)
    {
        auto name = boost::python::extract<std::string>(kw["name"])();

        auto value = pyobject_to_vref<double>(kw["value"]);

        stats_.emplace(std::move(name), std::move(value));

        return boost::python::object();
    }

    struct py_grammar {
        boost::python::dict globals;

        py_grammar(const PythonParser& parser, start_rule_payload& stats_) :
            globals(boost::python::import("builtins").attr("__dict__"))
        {
            RegisterGlobalsConditions(globals);
            RegisterGlobalsValueRefs(globals, parser);
            RegisterGlobalsSources(globals);
            RegisterGlobalsEnums(globals);

            globals["EmpireStatistic"] = boost::python::raw_function(
                [&stats_](const boost::python::tuple& args, const boost::python::dict& kw)
                { return py_insert_empire_statistics_(stats_, args, kw); });
        }

        boost::python::dict operator()() const { return globals; }
    };
}

namespace parse {
    start_rule_payload statistics(const PythonParser& parser, const boost::filesystem::path& path, bool& success) {
        start_rule_payload all_stats;

        for (const auto& file : ListDir(path, IsFOCScript)) {
            start_rule_payload stats_;
            if (detail::parse_file<grammar, start_rule_payload>(GetLexer(), file, stats_)) {
                for (auto& stat : stats_) {
                    auto maybe_inserted = all_stats.emplace(stat.first, std::move(stat.second));
                    if (!maybe_inserted.second) {
                        WarnLogger() << "Addition of second statistic with name " << maybe_inserted.first->first
                                     << " failed.  Keeping first statistic found.";
                    }
                }
            }
        }

        bool file_success = true;
        for (const auto& file : ListDir(path, IsFOCPyScript)) {
            start_rule_payload stats_;
            py_grammar p = py_grammar(parser, stats_);
            if (py_parse::detail::parse_file<py_grammar>(parser, file, p)) {
                for (auto& stat : stats_) {
                    auto maybe_inserted = all_stats.emplace(stat.first, std::move(stat.second));
                    if (!maybe_inserted.second) {
                        WarnLogger() << "Addition of second statistic with name " << maybe_inserted.first->first
                                     << " failed.  Keeping first statistic found.";
                    }
                }
            } else {
                file_success = false;
            }
        }

        success = file_success;
        return all_stats;
    }
}
