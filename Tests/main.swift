import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}
let rules = try DomainRules(text: " Example.COM \nexample.com\n\nnews.example.org.\n")
check(rules.domains == ["example.com", "news.example.org"], "Normalization and deduplication")
check(rules.blocks("EXAMPLE.COM."), "Exact host")
check(rules.blocks("a.b.example.com"), "Nested subdomains")
check(!rules.blocks("notexample.com"), "Domain boundary")
check(!rules.blocks("example.com.attacker.test"), "Suffix direction")
check(!rules.blocks("example.org"), "Parent of specific rule")
for invalid in ["https://example.com", "*.example.com", "example..com", "-example.com", "example.com:443", "\u{65E5}\u{672C}\u{8A9E}.jp"] {
    do {
        _ = try DomainRules(text: invalid)
        fatalError("Accepted invalid rule: \(invalid)")
    } catch {}
}
let empty = try DomainRules(text: "")
check(!empty.blocks("example.com"), "Empty rules")
print("Domain rule checks passed")
