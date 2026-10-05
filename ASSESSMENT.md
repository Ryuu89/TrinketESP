# Hydroxide → Matcha: análise de portabilidade para Rogue

Data: 2026-09-05. Etapa: investigação, sem ativar automações no jogo.

## Fontes e alcance

- Hydroxide: `ROGUE/rogue_ui.lua`, commit `6951b2a5c29e47ebde700f3897e50cc2d863e89c`, blob `d9f4709af6521e08a439d9f64f0174477e9a3c2e`.
- Arquivo completo obtido: 27.282 linhas. O inventário estrutural percorre o arquivo inteiro e registra 632 declarações/pontos de configuração e 220 nomes de métodos. Isso não equivale a uma auditoria formal de cada ramo do programa.
- Revisão aprofundada: reconhecimento de trinkets e ingredientes, ESP, coleta, movimento do bot, estados de emergência, hooks, dependências e loader.
- Documentação completa da LuaVM e README de UI Binding consultados. A documentação e os bindings da versão instalada apresentam diferenças; comportamento observado tem precedência sobre suposições.
- MCP local consultado apenas para identificação, índice e leituras de objetos/propriedades. Nenhum clique, tecla, movimento, remote, teleport, reset, alteração de memória ou execução do Hydroxide foi solicitado ao jogo.
- O usuário confirmou que está no menu e pediu que a investigação continue principalmente pelo Hydroxide. As consultas ao jogo foram encerradas após essa orientação.

Fontes externas:

- https://git.fable.bz/zyu/hydroxide/src/commit/6951b2a5c29e47ebde700f3897e50cc2d863e89c/ROGUE/rogue_ui.lua
- https://git.fable.bz/zyu/hydroxide/src/branch/main/loader.lua
- https://doc.wabisabi.mom/matcha/llms-full.txt
- https://github.com/cconstellation/MatchaScripts

## Conclusão

A interface, o gerenciamento de configurações e vários overlays podem ser reescritos. A identificação completa dos itens e a coleta ainda têm bloqueios concretos na versão instalada. O bot original não pode ser apresentado como uma conversão equivalente: depende de recursos internos ausentes no modo externo e de proteções que também não são transferíveis.

Não há evidência que permita garantir ausência de banimento. A afirmação sobre detecção da LuaVM não demonstra que movimento, coleta ou outras ações sejam aceitos pelo servidor. O código cliente do Hydroxide também não revela todas as validações atuais do servidor de Rogue.

## O que o Hydroxide faz

### Trinket ESP

Em `identify_trinket`, linha 4786, o nome é inferido por diferentes combinações de classe, MeshId, AssetId de UnionOperation, meshes filhos, cores e propriedades de ParticleEmitter. As regras incluem itens comuns, gemas, artefatos e itens de eventos. Ingredientes usam outra tabela de AssetId, nas linhas 791 e 5193.

A descoberta inicial do ESP, linha 8051, percorre os filhos diretos de Workspace e procura objetos chamados `Part` com filho `ID`. O nome do objeto, portanto, não é o nome do trinket. O ESP calcula região pelo marcador mais próximo em AreaMarkers, linha 4892; isso é aproximação espacial, não confirmação de limites de uma região.

O fallback da identificação original retorna `Opal`, linha 4875. Uma adaptação deve usar `Unclassified` quando faltarem dados: reproduzir esse fallback converteria falhas de leitura em nomes aparentemente confiáveis. `Part` + `ID` é um filtro de candidatos usado pelo original, não uma prova de que um objeto está disponível para coleta ou não é um alvo falso.

Não foi identificada, nos caminhos prioritários de descoberta/classificação/coleta revisados, uma validação independente que certifique todos os candidatos contra um sistema atual de anti-trinket-ESP. Isso não prova que tal sistema inexista no jogo. Sua implementação não pode ser deduzida apenas desses filtros do Hydroxide.

### Coleta

O Auto Trinket, linha 25312, mantém candidatos, encontra ClickDetector recursivamente, lê MaxActivationDistance, compara a distância do personagem e chama fireclickdetector. O bot usa o mesmo mecanismo, com filtros de categoria e controle de IDs, nas linhas 14442–14528. A rotina simples exclui Azael Horn; o bot tem seleção explícita de itens especiais.

Coleta de armas, ingredientes e bolsas usa APIs distintas, incluindo ClickDetector e firetouchinterest. Substituir cada chamada por um clique ou tecla genérica não preserva necessariamente o comportamento.

Uma alternativa externa seria projetar um alvo validado na tela e enviar input normal quando próximo e visível. Isso exige comprovar a identidade e o alvo de interação, medir as coordenadas e confirmar o resultado no inventário. Desaparecimento do objeto sozinho não confirma coleta pelo usuário. Essa alternativa permanece proposta, sem implementação ou teste nesta etapa.

### Bot e proteções

`SmoothTeleport`, linha 12531, controla estados do Humanoid, zera velocidades/desabilita colisões e usa TweenService para mover CFrame. O executor original faz essas operações dentro do ambiente Roblox; a LuaVM externa não oferece equivalência automática.

O bot também cria Parts temporárias como plataformas de estabilização, por exemplo nas linhas 14585 e 14644. Desativa CanTouch em obstáculos e gatilhos de monstros; usa tags de CollectionService para Danger/SnapCool; equipa ferramentas; espera sinais de personagens; usa remotes para Gate e retorno ao menu. O hook de FireServer, linha 21617, participa de várias mudanças de comportamento, incluindo supressão relacionada a queda enquanto o bot está ativo.

Os hooks iniciais, linhas 142, 157 e 202, dependem de hookfunction, checkcaller, closures, constantes/upvalues e callbacks internos. Eles não se tornam desnecessários apenas porque o programa foi convertido para outra VM.

O recurso `AA Bypass`, linha 8492, é marcado como experimental pelo próprio código. O início de rotas, linha 13751, exige Blatant Mode. Rotinas denominadas de emergência também podem usar BreakJoints, Kick e troca de servidor. Por causa de permadeath, essas ações não devem ser copiadas ou executadas como se fossem uma proteção universal.

## Compatibilidade

| Recurso | Situação no Matcha externo | Dependências / limites |
|---|---|---|
| Aba, toggles, hotkeys e configurações | Reimplementável | UI Binding próprio; ids persistentes, leitura real dos valores, desligamento limpo. |
| Marcadores de candidatos a trinket | Viável em princípio | Name, filhos, Position, WorldToScreen e Drawing. Não valida identidade ou legitimidade. |
| Nome e categoria de todos os trinkets | Parcial / bloqueado atualmente | MeshId falha nesta instalação; AssetId e propriedades de partículas não estão disponíveis nas leituras realizadas. |
| Distância e região do trinket | Reimplementável com ressalvas | Personagem spawnado e referências válidas; região é marcador mais próximo. |
| Auto pickup de trinkets | Sem port direto | fireclickdetector ausente; alcance do ClickDetector indisponível. Input normal seria outro mecanismo e requer validação posterior. |
| Ingredient ESP | Parcial | Identificação original depende de AssetId oculto. Marcador genérico não equivale ao nome correto. |
| Ore ESP | Viável em princípio | Descoberta em contêiner específico, nomes e posições; disponibilidade pode exigir propriedades adicionais. |
| Player/NPC ESP e alerta de proximidade | Viável em princípio | Personagens, partes e saúde precisam de leituras válidas; nem todos os metadados são expostos. |
| Alertas de moderador, Observe e ferramentas | Parcial | Lista estática nunca é cobertura completa; APIs de grupo, tags e inventário diferem. Ausência de alerta não significa servidor seguro. |
| Mana, estados e inventário | Parcial | Somente dados replicados e corretamente legíveis; StringValue e Color apresentaram inconsistências no teste. |
| Registro/importação/visualização de caminhos | Reimplementável | Dados e overlays são independentes do movimento. Paths do original podem exigir trajetos impossíveis de caminhar. |
| Execução do autofarm original | Sem equivalência confirmada | TweenService, Humanoid state, plataformas, CanTouch, hooks e remotes. Não habilitar uma tradução incompleta. |
| Bot andando por input normal | Possibilidade futura, não validada | Exige navegação própria, rotas caminháveis, obstáculos, morte/respawn e parada confiável; não reaproveita garantias do bot original. |
| Gate, serverhop, auto dialogue/craft | Sem port direto em modo externo | Dependências de remotes, equipagem e sinais; Hybrid Mode seria mudança de arquitetura. |
| Auto parry e silent aim | Parcial ou sem equivalência | Sinais de sons/animações e OnClientInvoke/hooks não correspondem às APIs externas; não são prioridade desta etapa. |
| AutoBard e macros de teclas | Reimplementável conforme o mecanismo | Input normal; a versão do Hydroxide usa firesignal em botões. O AutoBard existente permanece separado. |
| Ambiente, customização, freecam, chams | Avaliar individualmente | Muitos usam Instance.new, Lighting, alterações de GUI, Clone/Destroy ou métodos ausentes. Recursos nativos do Matcha podem substituir parte da apresentação. |
| Flight, noclip, no-fall, forcefield, AA | Sem preservação das proteções | Algumas escritas existem, mas isso não torna o conjunto original compatível ou seguro. |

## Evidência da instalação atual

- Endpoint `http://127.0.0.1:8765/mcp` respondeu e disponibilizou status, busca, árvore, decompilação, execução, logs e referência de API. Não foi necessário instalar OpenCode ou alterar a configuração do usuário.
- Rogue Gaia: PlaceId `5208655184`; universo GameId `1087859240`. Hybrid Mode estava desligado.
- Viewport informado: `1920 × 1200`. LocalPlayer.Character e o personagem em Live estavam ausentes; o usuário confirmou que estava no menu. Isso não é evidência de bug de personagem.
- Encontrados 18 objetos pelo filtro `Workspace` → filho `Part` com `ID`. São candidatos, não 18 coletas ou itens certificados.
- Alguns candidatos têm ClickDetector dentro de uma Part filha. Buscar apenas um detector diretamente no objeto perderia esses alvos.
- MeshPart.MeshId devolveu `failed to fetch text`. AssetId, SpecialMesh.MeshId, ParticleEmitter.Rate e MaxActivationDistance retornaram nil nas amostras.
- Valores de Color foram idênticos entre as amostras e os componentes retornaram 176/27/185, fora do intervalo 0–1 descrito para Color3. StringValue.Value apresentou caracteres ilegíveis. A causa não foi determinada; não atribuir automaticamente isso ao anti-ESP, ao menu ou a offsets desatualizados.
- `fireclickdetector`, `hookfunction` e `Instance` retornaram tipo nil. A referência do MCP informa que FireServer/InvokeServer exigem Hybrid Mode; não foram chamados.

## Arquitetura proposta para a primeira implementação

1. Restringir a execução ao universo Rogue `1087859240` e aos mapas Gaia/Khei confirmados (`5208655184`, `3541987450`). A tela de menu mantém automações inativas. O arquivo original também aceita outros PlaceIds; não copiá-los indiscriminadamente.
2. Descobrir candidatos em Workspace por polling moderado, com orçamento por atualização. Não varrer todos os descendentes a cada frame.
3. Classificar usando somente propriedades efetivamente legíveis. Manter o motivo da classificação e marcar como desconhecido qualquer caso ambíguo. Candidatos desconhecidos ficam excluídos da coleta.
4. Renderizar sobre um cache, em uma única conexão, com Drawing reutilizado e removido ao descarregar. Chaves por Address com invalidação por sessão/ciclo de vida, e não por igualdade de wrappers de Instance.
5. Atualizar UI e textos quando mudarem. Estado de detecção, classificação e motivo de pausa devem corresponder ao comportamento real.
6. Antes de implementar pickup, resolver a identificação e comprovar o mecanismo normal de interação. Cancelar input pendente em perda de foco, menu, RMB/Shift, morte, troca de personagem ou desligamento.
7. Tratar rota/afk/escape como módulos posteriores. Falta de informação sobre Danger ou alvo deve bloquear automação, não ser interpretada como ausência de perigo. Não executar reset, escape, servidor ou movimento como teste de inspeção.

## Pendências reais

- Determinar por fonte estática confiável ou atualização dos bindings como recuperar a identidade dos itens que o Matcha atual não lê. Não substituir AssetId por adivinhação de tamanho/cor.
- Verificar se dados necessários mudam após o spawn apenas quando o usuário estiver em condição apropriada para isso. Nenhuma ação depende de entrar no mapa agora.
- Validar projeção visual, interação e confirmação de coleta separadamente. A leitura de um objeto não valida clique; um clique não valida aceitação pelo servidor; uma coleta não prova ausência de detecção.
- O código do Hydroxide serve como referência de implementação, não como especificação completa do servidor ou garantia atual de proteção.

## Arquivos

- `references/hydroxide-6951b2a.lua.txt`: snapshot de fonte para consulta, deliberadamente salvo como texto e nunca executado.
- `references/matcha-documentation.txt`: documentação consultada.
- `references/source-index.json`: inventário estrutural completo, com linhas do snapshot.

O repositório Hydroxide declara licença AGPL-3.0-or-later. Atribuição e licença devem acompanhar código derivado em uma futura distribuição. Nenhum script foi publicado nesta etapa.
