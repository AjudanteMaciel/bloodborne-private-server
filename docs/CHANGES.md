# Alterações desta integração

## shadNet

Base: `5a849a192fd4450593c57b10697316ac324c856e` de Wozzardman/shadnet-p2p. O patch contém a implementação e os testes C++ correspondentes.

- STUN: aceita o enquadramento legado de quatro bytes e o moderno `FF83 FFFF FFFF` de seis bytes. A resposta usa o formato recebido; pacotes inválidos continuam rejeitados.
- Busca: compatibilidade entre anúncios cooperativos com juramento (tipo 5) e busca de helper tipo 0, preservando restrições de método, versão, identidade, área, zona, canal, distância, nível e senha.
- Altar: reconhece o helper no Sonho, método 1/tipo 0 ou 5, para a busca cooperativa de dungeon, com os mesmos controles de identidade, versão e senha/nível. Cobertura automatizada não equivale a confirmação de carregamento no cliente.
- Conversão opt-in: somente payload v3/224 bytes, papel 21 e anúncio Vileblood isolado, recebido por um filtro cooperativo neutro preciso, pode mudar para papel 7 na resposta. Busca de adversário explícita e dados desconhecidos não são convertidos. Cooperativo desse par foi confirmado dentro do jogo.
- Mantida a normalização upstream do contador de disponibilidade no byte `0x79`.

O patch público contém fixtures com nomes, UUIDs de sessão e IDs de personagens substituídos por exemplos. Os dados e credenciais de uma rede real não fazem parte do projeto.

## Backend Python

Base: `08e56cd82c5cfafa76200946f3e08d1616108deb` de lKaniel/bloodborne-server.

- Restringe o bind ao endereço solicitado, em vez de escutar todas as interfaces.
- Busca de glifo também consulta o catálogo sintético de dungeons padrão.
- `ChannelWordSearch` devolve o registro na raiz da resposta, conforme o decoder do cliente, enquanto consultas de lista mantêm `ChannelList`.
- O teste de seleção de endereço roda em loopback: valida o `Host` HTTP sem exigir que um IP de LAN arbitrário exista na máquina de teste.

Nenhum banco de contas, conteúdo ou catálogo importado manualmente de uma instalação pessoal acompanha o projeto. Glifos de servidores anteriores não migram automaticamente para uma instalação nova.

## Limites da validação

A conexão de rede, a entrada na sala e a partida jogável são verificações diferentes. O relato manual registrado foi de partida cooperativa jogável e de um teste de PvP em Chalice. Não se declara cobertura integral do protocolo original, dos juramentos ou de todas as dungeons.
