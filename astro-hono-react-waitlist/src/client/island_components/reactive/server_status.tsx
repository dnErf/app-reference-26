import { useCallback, useEffect, useState } from "react";

export const ServerStatus = () => {
    const [status, setStatus] = useState<string>("");
    const fetchHealthStatus = useCallback(async () => {
        const responseJson = await (await fetch("/api/health")).json()
        setStatus(responseJson.ok ? "1" : "0")
    }, [])

    useEffect(() => {
        fetchHealthStatus()
    }, [])

    return (
        <div>
            <h1 className="text-lg text-center">
                Server Status {": "}
                <span>{status}</span>
            </h1>
            
        </div>
    )
}