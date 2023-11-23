make_greeter(f)
{
    greet(subject)  ; This will be a closure due to f.
    {
        MsgBox Format(f, subject)
    }
    return greet  ; Return the closure.
}

g := make_greeter("Hello, {}!")
g2 := make_greeter("Goodbye, {}!")
g(A_UserName)
g("World")
g2("World")