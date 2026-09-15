document.addEventListener(
    "DOMContentLoaded",
    () =>
    {
        console.log(
            "MPO2+ iniciado"
        );

        const statusMessage =
            document.getElementById(
                "statusMessage"
            );

        statusMessage.innerText =
            "Interface carregada com sucesso.";

        const btnPreview =
            document.getElementById(
                "btnPreview"
            );

        btnPreview.addEventListener(
            "click",
            () =>
            {
                statusMessage.innerText =
                    "Preview solicitado.";
                previewContainer.innerHTML =
                "<h3>SPARTAAAAA</h3>";
            }
        );
    }
);