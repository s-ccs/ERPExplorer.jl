"""
    start_harness_server(app; host, port)

Start the Bonito server for the harness app and print the URL.
"""
function start_harness_server(app; host::AbstractString = DEFAULT_HOST, port::Int = DEFAULT_PORT)
    if isdefined(Bonito, :Server)
        server = Bonito.Server(app, host, port)
        println("Open: http://$(host):$(port)")
        return server
    elseif isdefined(Bonito, :serve)
        url = Bonito.serve(app; host = host, port = port)
        println("Open: ", url)
        return nothing
    else
        error("No Bonito.Server or Bonito.serve found in this Bonito version.")
    end
end
